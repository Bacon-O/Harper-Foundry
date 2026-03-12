#!/bin/bash
set -e

# 1. Load Fuel Mix
source "$(dirname "$0")/env_setup.sh" "$@"

echo "🌡️  Furnace Preheat: Auditing Charge Materials..."

# 2. Audit the 'Blueprint' (Params)
if [[ -z "$TARGET_ARCH" ]]; then
    echo "❌ ERROR: Charge failed. TARGET_ARCH is missing from the blueprint."
    exit 1
fi

# 3. Audit the 'Ore' (Using REPO_ROOT for stability)
echo "🔍 Checking Input Materials..."

# TUNING_CONFIG is optional - only validate if set
if [[ -n "$TUNING_CONFIG" ]]; then
    if [[ ! -f "${REPO_ROOT}/configs/configs.d/$TUNING_CONFIG" ]] && [[ ! -f "${REPO_ROOT}/configs/$TUNING_CONFIG" ]]; then
        echo "❌ ERROR: Missing Charge Material: $TUNING_CONFIG (not found in configs/ or configs.d/)"
        exit 1
    fi
fi

_artifact_delivery_lc="${ARTIFACT_DELIVERY,,}"
_artifact_compression_lc="${ARTIFACT_COMPRESSION,,}"
_artifact_delivery_method_lc="${ARTIFACT_DELIVERY_METHOD,,}"

if [[ "$_artifact_delivery_lc" == "true" ]]; then
    if [[ -z "$_artifact_delivery_method_lc" ]]; then
        echo "❌ ERROR: ARTIFACT_DELIVERY_METHOD must be set when ARTIFACT_DELIVERY is true."
        exit 1
    fi

    if [[ "$_artifact_delivery_method_lc" == "scp" || "$_artifact_delivery_method_lc" == "sftp" ]]; then
        if [[ -z "$REMOTE_DELIVERY_HOST" || -z "$REMOTE_DELIVERY_USER" || -z "$REMOTE_DELIVERY_PATH" ]]; then
            echo "❌ ERROR: REMOTE_DELIVERY_HOST, REMOTE_DELIVERY_USER, and REMOTE_DELIVERY_PATH must be set for remote delivery."
            exit 1
        fi
    elif [[ "$_artifact_delivery_method_lc" == "rsync" ]]; then
        if [[ -z "$REMOTE_DELIVERY_HOST" || -z "$REMOTE_DELIVERY_USER" || -z "$REMOTE_DELIVERY_PATH" ]]; then
            echo "❌ ERROR: REMOTE_DELIVERY_HOST, REMOTE_DELIVERY_USER, and REMOTE_DELIVERY_PATH must be set for remote delivery."
            exit 1
        fi
    elif [[ -n "$LOCAL_DELIVERY_PATH" ]]; then
        echo "⚠️  Warning: LOCAL_DELIVERY_PATH is set but will be ignored since ARTIFACT_DELIVERY_METHOD is not configured for local delivery."
    fi

    # connection test for remote delivery
    if [[ "$_artifact_delivery_method_lc" == "scp" || "$_artifact_delivery_method_lc" == "sftp" ]] || [[ "$_artifact_delivery_method_lc" == "rsync" ]]; then
        echo "🔗 Testing connectivity to scp/sftp remote delivery host: $REMOTE_DELIVERY_USER@$REMOTE_DELIVERY_HOST"
        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_DELIVERY_USER@$REMOTE_DELIVERY_HOST" "echo 'Connection successful'"; then
            echo "❌ ERROR: Unable to connect to remote delivery host $REMOTE_DELIVERY_HOST with user $REMOTE_DELIVERY_USER. Please check your network connection and credentials."
            exit 1
        fi
        echo "✅ Remote delivery host connectivity verified."  
    fi
fi

if [[ ! "$BASE_CONFIG" == "defconfig" && ! "$BASE_CONFIG" == "tinyconfig" ]]; then
    if [[ ! -f "${REPO_ROOT}/configs/configs.d/$BASE_CONFIG" ]] && [[ ! -f "${REPO_ROOT}/configs/$BASE_CONFIG" ]]; then
        echo "❌ ERROR: Missing Charge Material: $BASE_CONFIG (not found in configs/ or configs.d/)"
        exit 1
    fi
fi

# 4. Infrastructure Check
if [[ ! -d "$BUILD_WORKSPACE_DIR" ]]; then
    echo "❌ ERROR: The Crucible (Block Volume) is not mounted at $BUILD_WORKSPACE_DIR"
    exit 1
fi

# 5. Tooling Check (Synced with foundry_template.params)
dependencies=(docker) 

if [[ "$ENABLE_QEMU_TESTS" == "true" ]]; then
    dependencies+=(qemu-system-x86_64)
    echo "🛡️  QA Mode Active: Ensuring QEMU tools are ready..."
    
    echo "Checking for safe_initrd.img for QEMU tests..."
    if [[ ! -f "$(dirname "$0")/plugins/qatest/tests/safe_initrd.img" ]]; then
        echo "❌ ERROR: safe_initrd.img not found at $(dirname "$0")/plugins/qatest/tests/safe_initrd.img"
        echo "   This is required for QEMU boot testing. Please ensure it is present."
        echo "   You can generate it using: scripts/plugins/tools/generate_safe_initrd.sh"
        exit 1
    fi
    echo "File safe_initrd.img found."
fi

for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ ERROR: Required Tooling '$cmd' not found on host."
        exit 1
    fi
done

# Sanity check: ensure the QEMU bridge is accessible inside the container for cross-compilation
# Only required when host architecture differs from target architecture
if [[ "$HOST_ARCH" != "x86_64" ]] && [[ "$TARGET_ARCH" == "x86_64" ]]; then
    if [[ ! -f "/usr/bin/qemu-x86_64-static" ]]; then
        echo "❌ ERROR: Cross-compilation detected (HOST: $HOST_ARCH, TARGET: x86_64)"
        echo "   QEMU static binary required: /usr/bin/qemu-x86_64-static"
        echo "   Ensure you are mounting it with: -v /usr/bin/qemu-x86_64-static:/usr/bin/qemu-x86_64-static:ro"
        exit 1
    fi
    echo "🔗 Cross-compilation detected: Using QEMU x86_64-static for $HOST_ARCH -> x86_64 build."
fi

echo "✅ Charge Materials Verified. The environment is heat-ready."