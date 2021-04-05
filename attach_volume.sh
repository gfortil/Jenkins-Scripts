#!/bin/bash

# ---
# Create log for provisioning script and output stdout and stderr to it
# ---
LOG=/var/log/provisioner.log
exec > $LOG 2>&1
set -x

ISDEBIAN=false

if [ -e /etc/lsb-release ]; then
	DISTRO=$(cat /etc/os-release | grep UBUNTU_CODENAME | cut -b 17-)
    ISDEBIAN=true
fi

mountpoint=/mnt/vdb
device=/dev/vdb

# Set timezone
# export TZ="/usr/share/zoneinfo/America/${timezone}"
# echo "export TZ=\"/usr/share/zoneinfo/America/${timezone}\"" >> ~/.bashrc
# $(cat ~/.bashrc | TZ)

# ---
# Format and mount filesystems
# ---

if [ "$(df -Th | grep ${device} | awk '{print $1}')" == "${device}" ]
then
    echo "${device} has already been mounted."
else
    echo "Format ${device}"

    # This block is necessary to prevent provisioner from continuing before volume is attached
    while [ ! -b ${device} ]; do sleep 1; done

    UUID=$(lsblk -no UUID ${device})

    if [ -z $UUID ]
    then
        mkfs.ext4 ${device}
    fi
    
    if [ ! -d ${mountpoint} ]
    then
        mkdir -p ${mountpoint}
    fi
    
    sleep 5

    grep ${mountpoint} /etc/fstab
    if [ $? -ne 0 ]
    then
        echo "Add ${device} to /etc/fstab"
        echo "UUID=$UUID ${mountpoint}    xfs    noatime    0 0" >> /etc/fstab
    fi

    echo "Mount ${device}"
    mount ${device} ${mountpoint}
fi

df -h

# ---
# Add hostname to /etc/hosts
# ---

grep `hostname` /etc/hosts
if [ $? -ne 0 ]
then
    echo "Add hostname and ip to /etc/hosts"
    echo "${ip} `hostname -s` `hostname`" >> /etc/hosts
fi

# ---
# Move directories from bootdisk to mountpoint
# ---
move_dir () {
    if [ ! -d ${mountpoint}$1 ] # if directory doesn't exist on the mounted volume
    then
        mkdir -p -m 777 ${mountpoint}$1
	chown ${DISTRO}:${DISTRO} ${mountpoint}$1 -R
        if [ -d $1 ] # if directory exists on root volume
        then
            mv $1 ${mountpoint}$(dirname "$1")
        fi
        ln -s ${mountpoint}$1 $1
    fi
}

move_dir /var/lib/HPCCSystems
move_dir /opt/HPCCSystems
move_dir /etc/HPCCSystems
move_dir /jenkins

if [ ${ISDEBIAN} == true ]
then
    apt-get update
    apt-get install -y openjdk-8-jre-headless
    apt-get install -y wget 
else
    yum install java-1.8.0-openjdk -y
    yum install wget -y
fi

exit 0
