#!/bin/bash
set -x

get_local_disks()
{      
    DEVICE_NAME=$1
    
    # Dump the current disk config for debugging
    fdisk -l
    
    # Dump the scsi config
    lsscsi
    
    # Get the root/OS disk so we know which device it uses and can ignore it later
    rootDevice=`mount | grep "on / type" | awk '{print $1}' | sed 's/[0-9]//g'`
    
    # Get the TMP disk so we know which device and can ignore it later
    tmpDevice=`mount | grep "on /mnt/resource type" | awk '{print $1}' | sed 's/[0-9]//g'`

    # Get the metadata and storage disk sizes from fdisk, we ignore the disks above
    metadataDiskSize=`fdisk -l | grep '^Disk /dev/' | grep -v $rootDevice | grep -v $tmpDevice | awk '{print $3}' | sort -n -r | tail -1`
    storageDiskSize=`fdisk -l | grep '^Disk /dev/' | grep -v $rootDevice | grep -v $tmpDevice | awk '{print $3}' | sort -n | tail -1`

    # Compute number of disks
    nbDisks=`fdisk -l | grep '^Disk /dev/' | grep -v $rootDevice | grep -v $tmpDevice | wc -l`
    echo "nbDisks=$nbDisks"
    let nbMetadaDisks=nbDisks
    let nbStorageDisks=nbDisks
        
    if is_convergednode; then
        # If metadata and storage disks are the same size, we grab 1/3 for meta, 2/3 for storage
        
        # minimum number of disks has to be 2
        let nbMetadaDisks=nbDisks/3
        if [ $nbMetadaDisks -lt 2 ]; then
            let nbMetadaDisks=2
        fi
        
        let nbStorageDisks=nbDisks-nbMetadaDisks
    fi
    
    echo "nbMetadaDisks=$nbMetadaDisks nbStorageDisks=$nbStorageDisks"			
    
    metadataDevices="`fdisk -l | grep '^Disk /dev/' \
        | grep $metadataDiskSize | awk '{print $2}' \
        | awk -F: '{print $1}' | sort | head -$nbMetadaDisks \
        | tr '\n' ' ' | sed 's|/dev/||g'`"
    storageDevices="`fdisk -l | grep '^Disk /dev/' \
        | grep $storageDiskSize | awk '{print $2}' \
        | awk -F: '{print $1}' | sort | tail -$nbStorageDisks \
        | tr '\n' ' ' | sed 's|/dev/||g'`"

    case "$DEVICE_NAME" in
            meta)
                return "$metadataDevices"
                ;;
            
            storage)
                return "$storageDevices"
                ;;
    esac
}

setup_storage_disks()
{
    #replace with jq
    mount=$1
    raidDevice=$2

    BEEGFS_ROOT=`jetpack config beegfs.root_dir || echo "/data/beegfs"`
    STORAGE_LUNS=`jetpack config cyclecloud.mounts.${mount}.luns 0`
    filesystem=`jetpack config beegfs.disk_mounts.${mount}.type || echo "ext4"`
    VOLUME_TYPE=`jetpack config beegfs.disk_mounts.${mount}.raid_level || echo "0"`
    FS_OPTS=`jetpack config beegfs.disk_mounts.${mount}.fs_options || echo "-i 2048 -I 512 -J size=400 -Odir_index,filetype"`
    MOUNT_OPTS=`jetpack config beegfs.disk_mounts.${mount}.options || echo "noatime,nodiratime,nobarrier,nofail"`
    mountPoint=`jetpack config beegfs.disk_mounts.${mount}.mountpoint || echo "$BEEGFS_ROOT/$mount"`

    DISKS=""
    if [ "$STORAGE_LUNS" != "0" ]; then
        echo "Using managed disks"
        LUNS=${STORAGE_LUNS#"["}
        LUNS=${LUNS%"]"}
        LUNS=$(echo $LUNS | tr -d ",")
        for lun in $LUNS; do
            disk=`readlink -f /dev/disk/azure/scsi1/lun$lun`
            DISKS="$DISKS ${disk}"
        done
    else
        DISKS=$(get_local_disks $mount)
    fi

    createdPartitions=""

    for disk in $DISKS; do
        fdisk -l $disk || break
        fdisk $disk << EOF
n
p
1


t
fd
w
EOF
        createdPartitions="$createdPartitions ${disk}1"
        if [[ "$mount" == "meta" ]]; then
            dev=$(basename $disk)
            config_meta_device $dev
        fi
    done
    sleep 10
    mkdir -p $mountPoint
    # Create RAID-0/RAID-5 volume
    if [ -n "$createdPartitions" ]; then
        devices=`echo $createdPartitions | wc -w`
        mdadm --create /dev/$raidDevice --level $VOLUME_TYPE --raid-devices $devices $createdPartitions

        sleep 10

        mdadm /dev/$raidDevice

        if [ "$filesystem" == "xfs" ]; then
            mkfs -t $filesystem /dev/$raidDevice
            export xfsuuid="UUID=`blkid |grep dev/$raidDevice |cut -d " " -f 2 |cut -c 7-42`"
            #echo "$xfsuuid $mountPoint $filesystem rw,noatime,attr2,inode64,nobarrier,sunit=1024,swidth=4096,nofail 0 2" >> /etc/fstab
            echo "$xfsuuid $mountPoint $filesystem rw,noatime,attr2,inode64,nobarrier,sunit=1024,swidth=4096,nofail 0 2" >> /etc/fstab
        else
            #mkfs.ext4 -i 2048 -I 512 -J size=400 -Odir_index,filetype /dev/$raidDevice 
            mkfs.ext4 $FS_OPTS /dev/$raidDevice 
            sleep 5
            tune2fs -o user_xattr /dev/$raidDevice
            export ext4uuid="UUID=`blkid |grep dev/$raidDevice |cut -d " " -f 2 |cut -c 7-42`"
            #echo "$ext4uuid $mountPoint $filesystem noatime,nodiratime,nobarrier,nofail 0 2" >> /etc/fstab
            echo "$ext4uuid $mountPoint $filesystem noatime,nodiratime,nobarrier,nofail 0 2" >> /etc/fstab
        fi

        sleep 10

        mount -a
    fi

    if [[ "$mount" == "meta" ]]; then
        config_meta_host 
    fi
}

config_meta_device()
{
    dev=$1
    echo deadline > /sys/block/${dev}/queue/scheduler
    echo 128 > /sys/block/${dev}/queue/nr_requests
    echo 128 > /sys/block/${dev}/queue/read_ahead_kb
    echo 256 > /sys/block/${dev}/queue/max_sectors_kb
}

config_meta_host()
{
    echo 5 > /proc/sys/vm/dirty_background_ratio
    echo 20 > /proc/sys/vm/dirty_ratio
    echo 50 > /proc/sys/vm/vfs_cache_pressure
    echo 262144 > /proc/sys/vm/min_free_kbytes
    echo 1 > /proc/sys/vm/zone_reclaim_mode
    
    echo always > /sys/kernel/mm/transparent_hugepage/enabled
    echo always > /sys/kernel/mm/transparent_hugepage/defrag
}

set_hostname()
{
    HOSTNAME=`jetpack config fqdn || return 1`
    sed -i 's|^HOSTNAME.*|HOSTNAME='$HOSTNAME'|g' /etc/sysconfig/network
}

setup_storage_disks "meta" "md10"
setup_storage_disks "storage" "md20"
set_hostname
