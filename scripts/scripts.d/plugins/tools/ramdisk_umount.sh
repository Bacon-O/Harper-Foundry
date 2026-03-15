#!/bin/bash
set -e

source "$(dirname "$0")/../../../env_setup.sh" "$@"
source "$(dirname "$0")/ramdisk_control.sh"

echo "Unmounting RAM disk for build environment..."
ramkdisk_control stop
ramkdisk_control status
echo "RAM disk unmounted from $RAMDISK_MOUNT_POINT."