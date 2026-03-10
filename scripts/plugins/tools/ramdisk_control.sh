#!/bin/bash
set -e
##########################################################################################################
# Template for 48GB RAM disk, mounting ton /mnt/ramdisk
# TODO make a script to install and configure
##########################################################################################################
# [Unit]
# Description=Build RAM Disk 48GB
# After=local-fs.target

# [Service]
# Type=oneshot
# RemainAfterExit=yes
# ExecStart=/usr/bin/mount -t tmpfs -o size=4G,mode=0755,uid=debian,gid=debian tmpfs /mnt/ramdisk
# ExecStop=/usr/bin/umount /mnt/ramdisk

# [Install]
# WantedBy=multi-user.target
##########################################################################################################
#
# System commands to enabled server
#
# sudo nano /etc/systemd/system/ramdisk-48GB.service
# sudo systemctl daemon-reload
# sudo systemctl status ramdisk-48GB.service 
##########################################################################################################
#
# Security and permission commands
#
# nano /etc/sudoers.d/debian-ramdisk.conf
# Allows the debian user to run the ramdisk-48GB service
# debian ALL=(ALL) NOPASSWD: /usr/bin/systemctl status ramdisk-48GB.service, /usr/bin/systemctl start ramdisk-48GB.service, /usr/bin/systemctl stop ramdisk-48GB.service, /usr/bin/systemctl restart ramdisk-48GB.service

# Required env vars:
# RAMDISK_MOUNT_POINT - The mount point for the RAM disk (e.g., /mnt/ramdisk)
# RAMDISK_SERVICE_NAME - The name of the systemd service managing the RAM disk (e.g., ramdisk-48GB.service)

source "$(dirname "$0")/../../env_setup.sh" "$@"

ramkdisk_control() {
    command=""
    case "$1" in
        start)
            command="start"
            ;;
        stop)
            command="stop"
            ;;
        status)
            command="status"
            ;;
        restart)
            command="restart"
            ;;
        *)
            echo "Usage: $0 {start|stop|status|restart}"
            exit 1
            ;;
    esac   
    
    if [[ -z "$RAMDISK_MOUNT_POINT" ]]; then
        echo "RAMDISK_MOUNT_POINT environment variable is not set. Please set it to the mount point of the RAM disk."
        exit 1
    fi

    if [[ -z "$RAMDISK_SERVICE_NAME" ]]; then
        echo "RAMDISK_SERVICE_NAME environment variable is not set. Please set it to the name of the systemd service managing the RAM disk."
        exit 1
    fi

    echo "Executing: sudo systemctl $command $RAMDISK_SERVICE_NAME"
    sudo systemctl "$command" "$RAMDISK_SERVICE_NAME"
    return 0
}