#!/bin/bash
set -e

# 1. Load Fuel Mix
source "$(dirname "$0")/env_setup.sh" "$@"

echo "🌡️  Furnace Preheat: Auditing Charge Materials..."

# 2. Audit the 'Blueprint' (Params)
if [ -z "$TARGET_ARCH" ]; then
    echo "❌ ERROR: Charge failed. TARGET_ARCH is missing from the blueprint."
    exit 1
fi

# 3. Audit the 'Ore' (Using REPO_ROOT for stability)
echo "🔍 Checking Input Materials..."

# TUNING_CONFIG is optional - only validate if set
if [ -n "$TUNING_CONFIG" ]; then
    TUNING_PATH="${REPO_ROOT}/configs/$TUNING_CONFIG"
    if [ ! -f "$TUNING_PATH" ]; then
        echo "❌ ERROR: Missing Charge Material: $TUNING_PATH"
        exit 1
    fi
fi

if [[ "$BASE_CONFIG" != "defconfig" && "$BASE_CONFIG" != "tinyconfig" ]]; then
    BASE_PATH="${REPO_ROOT}/configs/$BASE_CONFIG"
    if [ ! -f "$BASE_PATH" ]; then
        echo "❌ ERROR: Missing Base Material: $BASE_PATH"
        exit 1
    fi
fi

# 4. Infrastructure Check
if [ ! -d "$PROJECT_ROOT" ]; then
    echo "❌ ERROR: The Crucible (Block Volume) is not mounted at $PROJECT_ROOT"
    exit 1
fi

# 5. Tooling Check (Synced with foundry.params)
dependencies=(docker) 

if [ "$ENABLE_QEMU_TESTS" == "true" ]; then
    dependencies+=(qemu-system-x86_64)
    echo "🛡️  QA Mode Active: Ensuring QEMU tools are ready..."
fi

for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ ERROR: Required Tooling '$cmd' not found on host."
        exit 1
    fi
done

# Sanity check: ensure the QEMU bridge is accessible inside the container for cross-compilation
# Only required when host architecture differs from target architecture
if [ "$HOST_ARCH" != "x86_64" ] && [ "$TARGET_ARCH" == "x86_64" ]; then
    if [ ! -f "/usr/bin/qemu-x86_64-static" ]; then
        echo "❌ ERROR: Cross-compilation detected (HOST: $HOST_ARCH, TARGET: x86_64)"
        echo "   QEMU static binary required: /usr/bin/qemu-x86_64-static"
        echo "   Ensure you are mounting it with: -v /usr/bin/qemu-x86_64-static:/usr/bin/qemu-x86_64-static:ro"
        exit 1
    fi
    echo "🔗 Cross-compilation detected: Using QEMU x86_64-static for $HOST_ARCH -> x86_64 build."
fi

echo "✅ Charge Materials Verified. The environment is heat-ready."