#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to CHECK_LIST, HOST_DIST_BASE, and TEST_RUN_MODE
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
MISSING_COUNT=0

for CHECK in "${CHECK_LIST[@]}"; do
    # Grep for the exact config line (Fixed string, whole line match)
    if grep -Fxq "$CHECK" "$CONFIG_FILE"; then
        echo "  ✅ FOUND: $CHECK"
    else
        # If we are in Test Run mode, we warn but do not fail
        if [ "$TEST_RUN_MODE" == "true" ]; then
            echo "  ⚠️  MISSING (IGNORED FOR TEST): $CHECK"
        else
            echo "  ❌ MISSING: $CHECK"
            MISSING_COUNT=$((MISSING_COUNT + 1))
        fi
    fi
done

# Fail logic: Only if NOT in test mode and items are missing
if [ "$MISSING_COUNT" -gt 0 ]; then
    echo "🚨 Chemical Audit Failed: $MISSING_COUNT critical elements missing."
    exit 1
elif [ "$TEST_RUN_MODE" == "true" ] && [ "$MISSING_COUNT" -gt 0 ]; then
    echo "🧪 Test Mode: Chemical Audit bypassed $MISSING_COUNT warnings."
else
    echo "✅ Chemical Audit Passed."
fi

# --- STAGE 2: PHYSICAL AUDIT (Binary Check) ---
echo "⚖️  Stage 2: Dimensional Audit..."

# Check 1: Non-Zero Size
if [ ! -s "$KERNEL_IMAGE" ]; then
    echo "  ❌ ERROR: bzImage is 0 bytes (Empty File)."
    exit 1
fi

# Check 2: Correct File Type (Magic Bytes)
# We look for "Linux kernel" and "x86 boot" signatures
if file "$KERNEL_IMAGE" | grep -qE "Linux kernel.*x86 boot executable"; then
    echo "  ✅ Valid x86_64 Boot Executable"
    
    # Optional: Print size for observability
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
    # Note: If you implement QEMU later, the logic goes here.
    # For now, we acknowledge the flag.
    echo "   (QEMU Logic Placeholder)"
else
    echo "⏩ Stage 3: Stress Test Bypassed (QEMU disabled or Test Mode)."
fi

echo "✅ Material Analysis Complete. Artifact is ready for distribution."