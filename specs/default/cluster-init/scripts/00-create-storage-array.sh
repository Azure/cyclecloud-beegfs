#!/bin/bash
set -x

get_local_disks()
{      
    DEVICE_NAME=$1
    
    # Dump the current disk config for debugging
    fdisk -l
    
    # Dump the scsi config 
    #lsscsi 
    
    # Get the root/OS disk so we know which device it uses and can ignore it later
    rootDevice=`mount | grep "on / type" | awk '{print $1}' | sed 's/[0-9]//g'`
    
    # Get the TMP disk so we know which device and can ignore it later
    tmpDevice=`mount | grep "on /mnt/resource type" | awk '{print $1}' | sed 's/[0-9]//g'`
    if [ -z "$tmpDevice" ]; then
        tmpDevice=`mount | grep "on /mnt type" | awk '{print $1}' | sed 's/[0-9]//g'`
    fi

    # Compute number of disks
    nbDisks=`fdisk -l | grep '^Disk /dev/' | grep -v $rootDevice | grep -v $tmpDevice | grep -v /dev/md | wc -l`
    echo "nbDisks=$nbDisks"

    if [ "$nbDisks" == 0 ]; then return 0; fi

    let nbMetadaDisks=nbDisks
    let nbStorageDisks=nbDisks
    
    # minimum number of disks has to be 1
    let nbMetadaDisks=nbDisks/3
    if [ $nbMetadaDisks -lt 1 ]; then
        let nbMetadaDisks=1
    fi
    
    let nbStorageDisks=nbDisks-nbMetadaDisks
    
    echo "nbMetadaDisks=$nbMetadaDisks nbStorageDisks=$nbStorageDisks"			
    
    metadataDevices="`fdisk -l | grep '^Disk /dev/' | awk '{print $2}' | grep -v $rootDevice | grep -v $tmpDevice | grep -v /dev/md | awk -F: '{print $1}' | sort | head -n $nbMetadaDisks | tr '\n' ' '`"
    storageDevices="`fdisk -l | grep '^Disk /dev/' | awk '{print $2}' | grep -v $rootDevice | grep -v $tmpDevice | grep -v /dev/md | awk -F: '{print $1}' | sort | tail -n $nbStorageDisks | tr '\n' ' '`"

    
    case "$DEVICE_NAME" in
            meta)
                DISKS="$metadataDevices"
                ;;
            
            storage)
                DISKS="$storageDevices"
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
        PARTITION=1
    else
        get_local_disks $mount
        PARTITION=p1
    fi
    if [ "$nbDisks" == 0 ]; then return 0; fi
    # if no disks abort
    
    createdPartitions=""
    echo "DISKS=$DISKS"
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
        createdPartitions="$createdPartitions ${disk}${PARTITION}"
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
        if (( devices > 1 )); then
            mdadm --create /dev/$raidDevice --level $VOLUME_TYPE --raid-devices $devices $createdPartitions
            sleep 10
            mdadm /dev/$raidDevice
            FS_DEVICE="/dev/$raidDevice"
        else
            FS_DEVICE=`echo "$createdPartitions"`
        fi

        if [ "$filesystem" == "xfs" ]; then
            mkfs -t $filesystem $FS_DEVICE
            export xfsuuid="UUID=`blkid |grep $FS_DEVICE |cut -d " " -f 2 |cut -c 7-42`"
            #echo "$xfsuuid $mountPoint $filesystem rw,noatime,attr2,inode64,nobarrier,sunit=1024,swidth=4096,nofail 0 2" >> /etc/fstab
            echo "$xfsuuid $mountPoint $filesystem rw,noatime,attr2,inode64,nobarrier,sunit=1024,swidth=4096,nofail 0 2" >> /etc/fstab
        else
            #mkfs.ext4 -i 2048 -I 512 -J size=400 -Odir_index,filetype /dev/$raidDevice 
            mkfs.ext4 $FS_OPTS $FS_DEVICE
            sleep 5
            tune2fs -o user_xattr $FS_DEVICE
            export ext4uuid="UUID=`blkid |grep $FS_DEVICE |cut -d " " -f 2 |cut -c 7-42`"
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
    PLATFORM=`jetpack config platform`
    case $PLATFORM in
        ubuntu)      
             hostnamectl set-hostname --static `hostname`
            ;;
        centos)      
            HOSTNAME=`jetpack config fqdn || return 1`
            sed -i 's|^HOSTNAME.*|HOSTNAME='$HOSTNAME'|g' /etc/sysconfig/network
            ;;
    esac
}

setup_storage_disks "meta" "md10"
setup_storage_disks "storage" "md20"
set_hostname
