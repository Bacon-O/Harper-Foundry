#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to CHECK_LIST, WARN_LIST, and HOST_DIST_BASE
source "$(dirname "$0")/env_setup.sh" "$@"

echo "🕵️  Starting Material Analysis: Chemical & Physical Audit..."

# 2. Locate the Latest Artifact
# We look for folders in the DIST_BASE, sort by time (newest first), and pick the top one.
LATEST_BUILD_DIR=$(find "$HOST_DIST_BASE" -maxdepth 1 -type d -name "build_*" -printf "%T@ %p\n" | sort -n | tail -1 | cut -f2- -d" ")

if [ -z "$LATEST_BUILD_DIR" ]; then
    echo "❌ ERROR: No build artifacts found in $HOST_DIST_BASE"
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

# --- STAGE 1: CHEMICAL AUDIT (Configuration Check) ---
echo "📊 Stage 1: Auditing Composition..."
MISSING_CRITICAL=0

# Part A: Critical Elements (Must Pass)
echo "🛡️  Checking Critical Systems..."
for CHECK in "${CHECK_LIST[@]}"; do
    if grep -Fq "$CHECK" "$CONFIG_FILE"; then
        echo "   ✅ CONFIRMED: $CHECK"
    else
        echo "   ❌ CRITICAL FAILURE: $CHECK is MISSING."
        MISSING_CRITICAL=$((MISSING_CRITICAL + 1))
    fi
done

# Part B: Optional Elements (Warn Only)
echo "⚠️  Checking Optional Systems..."
if [ "${#WARN_LIST[@]}" -gt 0 ]; then
    for CHECK in "${WARN_LIST[@]}"; do
        if grep -Fq "$CHECK" "$CONFIG_FILE"; then
            echo "   ✅ OPTIONAL: $CHECK detected."
        else
            echo "   🔸 MISSING: $CHECK not found."
            echo "      (Acceptable: Likely running in Fallback Mode)"
        fi
    done
else
    echo "ℹ️  No optional checks defined."
fi

# Fail Logic: Only block build if CRITICAL items are missing
if [ "$MISSING_CRITICAL" -gt 0 ]; then
    if [ "$TEST_RUN_MODE" == "true" ]; then
        echo "🧪 Test Mode: Ignoring $MISSING_CRITICAL critical failures."
    else
        echo "🚨 Chemical Audit Failed: $MISSING_CRITICAL critical elements missing."
        exit 1
    fi
else
    echo "✅ Chemical Audit Passed."
fi

# --- STAGE 2: PHYSICAL AUDIT (Binary Check) ---
echo "⚖️  Stage 2: Dimensional Audit..."

# Check 1: Non-Zero Size (bzImage)
if [ ! -s "$KERNEL_IMAGE" ]; then
    echo "  ❌ ERROR: bzImage is 0 bytes (Empty File)."
    exit 1
fi

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

# --- STAGE 3: STRESS TEST (QEMU) ---
if [ "$ENABLE_QEMU_TESTS" == "true" ] && [ "$TEST_RUN_MODE" != "true" ]; then
    echo "🚀 Stage 3: Spawning Stress Test..."
    echo "   (QEMU Logic Placeholder)"
else
    echo "⏩ Stage 3: Stress Test Bypassed."
fi

echo "✅ Material Analysis Complete. Artifact is ready for distribution."