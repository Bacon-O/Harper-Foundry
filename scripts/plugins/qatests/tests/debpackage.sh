#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to QA_CRITICAL_CHECKS, QA_OPTIONAL_CHECKS, and HOST_OUTPUT_DIR
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

# Check 2: Debian Package Validation
echo "  📦 Checking for Debian Packages..."
DEB_COUNT=$(find "$LATEST_BUILD_DIR" -maxdepth 1 -name "*.deb" | wc -l)

if [ "$DEB_COUNT" -lt 2 ]; then
    echo "  ❌ ERROR: Missing Debian packages. Found: $DEB_COUNT (Expected at least 2: Image and Headers)."
    exit 1
else
    echo "  ✅ Found $DEB_COUNT .deb packages."
    # List them for the logs with sizes
    ls -lh "$LATEST_BUILD_DIR"/*.deb | awk '{print "     📦 " $9 " (" $5 ")"}'
fi

# Check 3: Correct File Type (Magic Bytes)
if file "$KERNEL_IMAGE" | grep -qE "Linux kernel.*x86 boot executable"; then
    echo "  ✅ Valid x86_64 Boot Executable"
    FILE_SIZE=$(du -h "$KERNEL_IMAGE" | cut -f1)
    echo "  📏 Payload Size: $FILE_SIZE"
else
    echo "  ❌ ERROR: Invalid File Type."
    echo "     Output: $(file "$KERNEL_IMAGE")"
    exit 1
fi

echo "✅ Debian Package Validation Passed."
exit 0