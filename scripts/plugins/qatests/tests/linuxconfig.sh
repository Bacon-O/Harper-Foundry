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

echo "📂 Analyzing Artifact: $LATEST_BUILD_DIR"

CONFIG_FILE="${LATEST_BUILD_DIR}/kernel.config"

# --- STAGE 1: CHEMICAL AUDIT (Configuration Check) ---
echo "📊 Stage 1: Auditing Composition..."
MISSING_CRITICAL=0
# Part A: Critical Elements (Must Pass)
echo "🛡️  Checking Critical Systems..."
for CHECK in "${QA_CRITICAL_CHECKS[@]}"; do
    if grep -Fq "$CHECK" "$CONFIG_FILE"; then
        echo "   ✅ CONFIRMED: $CHECK"
    else
        echo "   ❌ CRITICAL FAILURE: $CHECK is MISSING."
        MISSING_CRITICAL=$((MISSING_CRITICAL + 1))
    fi
done

# Part B: Optional Elements (Warn Only)
echo "⚠️  Checking Optional Systems..."
if [ "${#QA_OPTIONAL_CHECKS[@]}" -gt 0 ]; then
    for CHECK in "${QA_OPTIONAL_CHECKS[@]}"; do
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
