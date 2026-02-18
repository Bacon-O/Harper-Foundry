#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to BUILD_OUTPUT_DIR and other foundry variables
source "$(dirname "$0")/../../../env_setup.sh" "$@"

# 2. Use the Build Directory
# In QA-only mode, BUILD_OUTPUT_DIR is set directly by env_setup.sh to the test directory
# In normal mode, it's the latest build with timestamp
LATEST_BUILD_DIR="$BUILD_OUTPUT_DIR"

if [ -z "$LATEST_BUILD_DIR" ]; then
    echo "❌ ERROR: No build artifacts found in $HOST_OUTPUT_DIR"
    exit 1
fi

echo "🧪 Starting Test: Debian Package"
echo "📂 Analyzing Artifact: $LATEST_BUILD_DIR"

KERNEL_IMAGE="${LATEST_BUILD_DIR}/bzImage"

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

echo "✅ Test Passed: Debian Package"
exit 0