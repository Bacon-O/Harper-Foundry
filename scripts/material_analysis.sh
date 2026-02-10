#!/bin/bash
set -e

source "$(dirname "$0")/env_setup.sh" "$@"

echo "🕵️  Starting Material Analysis: Chemical & Physical Audit..."

LATEST_BUILD=$(ls -td "${HOST_DIST_BASE}"/build_*/ 2>/dev/null | head -n 1 | sed 's/\/*$//')
[[ -z "$LATEST_BUILD" ]] && echo "❌ ERROR: No output found." && exit 1

KERNEL_IMAGE="${LATEST_BUILD}/bzImage"
CONFIG_FILE="${LATEST_BUILD}/kernel.config"

# --- STAGE 1: CHEMICAL AUDIT ---
echo "📊 Stage 1: Auditing Composition..."
for FEATURE in "${CHECK_LIST[@]}"; do
    grep -q "^${FEATURE}" "$CONFIG_FILE" && echo "  ✅ $FEATURE" || (echo "  ❌ MISSING: $FEATURE" && exit 1)
done

# --- STAGE 2: PHYSICAL CHECK ---
echo "⚖️  Stage 2: Dimensional Audit..."
[[ ! -s "$KERNEL_IMAGE" ]] && echo "❌ ERROR: 0-byte bzImage!" && exit 1
file "$KERNEL_IMAGE" | grep -q "Linux kernel x86 boot executable" && echo "  ✅ Valid x86 Binary" || (echo "  ❌ Invalid File Type" && exit 1)

# --- STAGE 3: STRESS TEST ---
if [ "$ENABLE_QEMU_TESTS" == "true" ]; then
    echo "🚀 Stage 3: Spawning Stress Test..."
    # QEMU execution logic here...
else
    echo "⏩ Stage 3: Stress Test Bypassed (QEMU disabled)."
fi