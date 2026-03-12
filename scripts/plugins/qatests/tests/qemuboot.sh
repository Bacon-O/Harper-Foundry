#!/bin/bash
set -e

# 1. Load the Foundry Environment
# This ensures we have access to BUILD_OUTPUT_DIR and other foundry variables
source "$(dirname "$0")/../../../env_setup.sh" "$@"

# 2. Use the Build Directory
# In QA-only mode, BUILD_OUTPUT_DIR is set directly by env_setup.sh to the test directory
# In normal mode, it's the latest build with timestamp
LATEST_BUILD_DIR="$BUILD_OUTPUT_DIR"

if [[ -z "$LATEST_BUILD_DIR" ]]; then
    echo "❌ ERROR: No build artifacts found in $HOST_OUTPUT_DIR"
    exit 1
fi

echo "🧪 Starting Test: QEMU Boot"
echo "📂 Analyzing Artifact: $LATEST_BUILD_DIR"

KERNEL_IMAGE="${LATEST_BUILD_DIR}/bzImage"

# --- STAGE 3: STRESS TEST (QEMU) ---
if [[ "$ENABLE_QEMU_TESTS" == "true" ]] && [[ "$TEST_RUN_MODE" != "true" ]]; then
    echo "🚀 Stage 3: Spawning Stress Test..."

    if [[ ! -f "$KERNEL_IMAGE" ]]; then
        echo "❌ ERROR: bzImage not found in $LATEST_BUILD_DIR"
        exit 1
    fi

    if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
        echo "❌ ERROR: qemu-system-x86_64 not found in PATH"
        exit 1
    fi

    VM_MEM="${VM_MEM:-1G}"
    VM_CORES="${VM_CORES:-2}"
    VM_TIMEOUT="${VM_TIMEOUT:-15s}"

    # QEMU_OUTPUT=$(timeout "$VM_TIMEOUT" \
    #     qemu-system-x86_64 \
    #     -m "$VM_MEM" \
    #     -smp "$VM_CORES" \
    #     -kernel "$KERNEL_IMAGE" \
    #     -append "console=ttyS0 loglevel=4 panic=-1" \
    #     -nographic \
    #     -no-reboot \
    #     2>&1 || true)

    QEMU_OUTPUT=$(timeout "$VM_TIMEOUT" \
        qemu-system-x86_64 \
        -m "$VM_MEM" \
        -smp "$VM_CORES" \
        -cpu max \
        -kernel "$KERNEL_IMAGE" \
        -initrd "$(dirname "$0")/safe_initrd.img" \
        -append "console=ttyS0 nokaslr rdinit=/bin/sh" \
        -nographic \
        -no-reboot \
        2>&1 || true)



    if echo "$QEMU_OUTPUT" | grep -q "Linux version"; then
        echo "✅ QEMU boot check: kernel banner detected."
    else
        echo "❌ QEMU boot check failed: no kernel banner detected."
        echo "$QEMU_OUTPUT" | tail -n 50
        exit 1
    fi
else
    echo "⏩ Stage 3: Stress Test Bypassed."
fi

echo "✅ Test Passed: QEMU Boot"
exit 0