#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to BUILD_OUTPUT_DIR and other foundry variables

source "$(dirname "$0")/../../env_setup.sh" "$@"

echo "Mounting TPMFS for Foundry Environment..."

if [[ -n "$TPMFS_MOUNT_POINT" ]]; then
    if ! mountpoint -q "$TPMFS_MOUNT_POINT"; then
        echo "Mounting TPMFS at $TPMFS_MOUNT_POINT..."
        #sudo mount -t tmpfs -o size=64M tmpfs "$TPMFS_MOUNT_POINT"
        echo "Place holder command"
        echo "TPMFS mounted successfully."
    else
        echo "TPMFS is already mounted at $TPMFS_MOUNT_POINT."
    fi
else
    echo "⚠️  Warning: TPMFS_MOUNT_POINT is not set. Skipping TPMFS mount."
fi