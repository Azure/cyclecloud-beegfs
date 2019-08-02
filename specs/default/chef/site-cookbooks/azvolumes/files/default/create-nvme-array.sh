#!/bin/bash
set -x

setup_storage_disks()
{
    #replace with jq
    mount=$1
    raidDevice=$2

    STORAGE_LUNS=`jetpack config cyclecloud.mounts.${mount}.luns || echo "no drives to configure for $1"; return 0`
    filesystem=`jetpack config azvolumes.mounts.${mount}.type || echo "ext4"`
    VOLUME_TYPE=`jetpack config azvolumes.mounts.${mount}.raid_level || echo "0"`
    FS_OPTS=`jetpack config azvolumes.mounts.${mount}.fs_options || echo " "`
    MOUNT_OPTS=`jetpack config azvolumes.mounts.${mount}.options || echo "noatime,nodiratime,nobarrier,nofail"`
    mountPoint=`jetpack config azvolumes.mounts.${mount}.mountpoint `

    USE_NVME=true
    Disks=""

    nbDisks=`lsblk --raw -o name | grep -i nvme | grep -v n1p1 | wc -l`
    if [ "$nbDisks" -eq "0" ]; then
        echo "No NVMe disks attached";
        exit;
    fi

    Disks=`lsblk --raw -o name | grep -i nvme | grep -v n1p1 | xargs -I '{}' echo  /dev/'{}' | tr '\n' ' '`

    echo "Disks=$Disks"
    createdPartitions=""

    for disk in $Disks; do
        #disk=`readlink -f /dev/disk/azure/scsi1/lun$lun`
        fdisk -l $disk || break
        fdisk $disk << EOF
n
p
1


t
fd
w
EOF
        createdPartitions="$createdPartitions ${disk}p1"

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
        else
            #directly use the device
            raidDevice=`basename $createdPartitions`
        fi


        if [ "$filesystem" == "xfs" ]; then
            mkfs -t $filesystem /dev/$raidDevice
            export xfsuuid="UUID=`blkid |grep dev/$raidDevice |cut -d " " -f 2 |cut -c 7-42`"
            #echo "$xfsuuid $mountPoint $filesystem rw,noatime,attr2,inode64,nobarrier,sunit=1024,swidth=4096,nofail 0 2" >> /etc/fstab
            echo "$xfsuuid $mountPoint $filesystem rw,noatime,attr2,inode64,nobarrier,nofail 0 2" >> /etc/fstab
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
        chmod 777 $mountPoint
        mount -a
    fi

}


setup_storage_disks $1 $2
