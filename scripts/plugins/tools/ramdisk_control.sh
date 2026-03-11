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
# sudo nano /etc/polkit-1/rules.d/15-ramdisk.rules
# Group permission configuration
# polkit.addRule(function(action, subject) {
#     if (action.id == "org.freedesktop.systemd1.manage-units" &&
#         action.lookup("unit") == "ramdisk-48GB.service") {
#         if (subject.isInGroup("GROUPNAME")) {
#             return polkit.Result.YES;
#         }
#     }
# });
#
# User permission configuration
# polkit.addRule(function(action, subject) {
#     if (action.id == "org.freedesktop.systemd1.manage-units" &&
#         action.lookup("unit") == "ramdisk-48GB.service") {
#         if (subject.user == "USERNAME") {
#             return polkit.Result.YES;
#         }
#     }
# });
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

    echo "Executing: systemctl $command $RAMDISK_SERVICE_NAME"

    if [[ "$command" == "status" ]]; then
        # systemctl status returns 3 when unit is inactive, which is informational.
        if systemctl status "$RAMDISK_SERVICE_NAME"; then
            return 0
        fi

        status_rc=$?
        if [[ "$status_rc" -eq 3 ]]; then
            echo "Service '$RAMDISK_SERVICE_NAME' is inactive (systemctl rc=3)."
            return 0
        fi

        echo "Failed to query service status for '$RAMDISK_SERVICE_NAME' (rc=$status_rc)."
        return "$status_rc"
    fi

    systemctl "$command" "$RAMDISK_SERVICE_NAME"
    return 0
}