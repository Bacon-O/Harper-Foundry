#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to CHECK_LIST, WARN_LIST, and HOST_OUTPUT_DIR
source "$(dirname "$0")/../../env_setup.sh" "$@"

# 2. Locate Latest Build Directory
LATEST_BUILD_DIR=$(find "$HOST_OUTPUT_DIR" -maxdepth 1 -type d -name "build_*" -printf "%T@ %p\n" | sort -n | tail -1 | cut -f2- -d" ")

if [ -z "$LATEST_BUILD_DIR" ]; then
    echo "❌ ERROR: No build artifacts found in $HOST_OUTPUT_DIR"
    exit 1
fi

echo "📂 Analyzing Artifact: $LATEST_BUILD_DIR"

KERNEL_IMAGE="${LATEST_BUILD_DIR}/bzImage"
CONFIG_FILE="${LATEST_BUILD_DIR}/kernel.config"

# 3. Validation: Ensure files exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ ERROR: kernel.config not found in $LATEST_BUILD_DIR"
    exit 1
fi

if [ ! -f "$KERNEL_IMAGE" ]; then
    echo "❌ ERROR: bzImage not found in $LATEST_BUILD_DIR"
    exit 1
fi

# --- STAGE 2: PHYSICAL AUDIT (Binary Check) ---
echo "⚖️  Stage 2: Dimensional Audit..."

# Check 1: Non-Zero Size (bzImage)
if [ ! -s "$KERNEL_IMAGE" ]; then
    echo "  ❌ ERROR: bzImage is 0 bytes (Empty File)."
    exit 1
fi

echo "✅ Artifact Validation Passed: kernel.config and bzImage found."
exit 0