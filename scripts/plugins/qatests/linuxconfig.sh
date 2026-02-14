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
fi
    
echo "✅ Chemical Audit Passed."
exit 0
