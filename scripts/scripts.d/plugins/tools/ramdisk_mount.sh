#!/bin/bash
set -e

source "$(dirname "$0")/../../../env_setup.sh" "$@"
source "$(dirname "$0")/ramdisk_control.sh"

echo "Mounting RAM disk for build environment..."
ramkdisk_control start
ramkdisk_control status
echo "RAM disk mounted at $RAMDISK_MOUNT_POINT with the following details:"
df -h "$RAMDISK_MOUNT_POINT"
