#!/bin/bash
# === TEST CONFIGURATION ===
# Base path where the Foundry drops the 'dist' folder
BASE_PATH="/mnt/build-data/github_work/Debian-Harper/Debian-Harper/dist"

# Audit Requirements: Exact internal Kconfig names
# If these are MISSING, ensure your harper_tunes.config has the right 'infrastructure' flags.
CHECK_LIST=(
    "CONFIG_WINE_NTSYNC=y"
    "CONFIG_MZEN3=y"
    "CONFIG_PREEMPT_RT=y"
)

# QEMU Hardware Emulation Settings
VM_MEM="1G"
VM_CORES="4"
TIMEOUT_VAL="30s"

# Derived Variables (Find the most recent build folder)
LATEST_BUILD=$(ls -td "${BASE_PATH}"/build_*/ 2>/dev/null | head -n 1 | sed 's/\/*$//')
# ==========================

# 1. Validation of Build Directory
if [ -z "$LATEST_BUILD" ]; then
    echo "❌ ERROR: No build directories found in $BASE_PATH"
    exit 1
fi

# Set specific file paths
LOG_OUT="${LATEST_BUILD}/smoke_test_$(date +%Y%m%d_%H%M).log"
KERNEL_IMAGE=$(find "${LATEST_BUILD}" -name "bzImage" | head -n 1)
CONFIG_FILE="${LATEST_BUILD}/kernel.config"

echo "--- 🕵️ Harper Proving Ground: Smoke Test ---"
echo "📂 Testing Build: $(basename "$LATEST_BUILD")"

# --- STAGE 1: FEATURE AUDIT ---
echo "📊 Stage 1: Auditing Kernel Features..."
if [ -f "$CONFIG_FILE" ]; then
    AUDIT_FAIL=0
    for FEATURE in "${CHECK_LIST[@]}"; do
        if grep -q "^${FEATURE}" "$CONFIG_FILE"; then
            echo "  ✅ Found: $FEATURE"
        else
            echo "  ❌ MISSING: $FEATURE"
            AUDIT_FAIL=1
        fi
    done
    [ $AUDIT_FAIL -eq 1 ] && echo "🚨 Warning: Build failed the static feature audit!"
else
    echo "  ⚠️  Skip: kernel.config not found. (Static Audit bypassed)"
fi

# --- STAGE 2: BOOT TEST ---
echo "🚀 Stage 2: Spawning x86_64 Virtual Machine..."
if [ ! -f "$KERNEL_IMAGE" ]; then
    echo "❌ ERROR: No bzImage found at $KERNEL_IMAGE"
    exit 1
fi



# Clean Execution: 'tr' filters out binary/ANSI garbage for a clean log
timeout --foreground "$TIMEOUT_VAL" qemu-system-x86_64 \
    -kernel "$KERNEL_IMAGE" \
    -m "$VM_MEM" \
    -smp "$VM_CORES" \
    -nographic \
    -serial mon:stdio \
    -no-reboot \
    -append "console=ttyS0,115200 earlyprintk=serial,ttyS0,115200 loglevel=7 panic=-1" \
    | tr -cd '\11\12\15\40-\176' | tee "$LOG_OUT" || true

# --- STAGE 3: ANALYSIS ---
echo "------------------------------------------"
# Check for the Linux Banner
if grep -q "Linux version" "$LOG_OUT"; then
    echo "✅ BOOT: SUCCESS"
else
    echo "❌ BOOT: FAILED (No kernel banner found in logs)"
    exit 1
fi

# Check for NTSYNC Initialization
if grep -iq "ntsync: initialized" "$LOG_OUT"; then
    echo "🍷 NTSYNC: DRIVER READY"
else
    echo "🚨 NTSYNC: NOT FOUND IN DMESG"
    exit 1
fi

echo "✅ FINAL STATUS: HARPER-CERTIFIED BUILD."
echo "------------------------------------------"