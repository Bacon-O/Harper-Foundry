#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to BUILD_OUTPUT_DIR and other foundry variables
source "$(dirname "$0")/../../env_setup.sh" "$@"


echo "Mounting TPMFS for Foundry Environment..."

if [[ -n "$TPMFS_MOUNT_POINT" ]]; then
    if ! mountpoint -q "$TPMFS_MOUNT_POINT"; then
        echo "Unmounting TPMFS at $TPMFS_MOUNT_POINT..."
        #sudo umount "$TPMFS_MOUNT_POINT"
        echo "Place holder command"
        echo "TPMFS unmounted successfully."
    else
        echo "TPMFS is already unmounted at $TPMFS_MOUNT_POINT."
    fi
else
    echo "⚠️  Warning: TPMFS_MOUNT_POINT is not set. Skipping TPMFS unmount."
fi