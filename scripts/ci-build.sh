#!/bin/bash
set -e

# 1. Load Fuel (Handles params + identity)
source /opt/factory/scripts/env_setup.sh

# --- The "Hand-off" Trap ---
cleanup_internal() {
    echo "⚖️ Internal Fix: Reclaiming ownership for Host UID: $HOST_UID"
    # Reclaim everything in the build root AND the output dir
    # This ensures the GitHub Runner can delete the source code too
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_BUILD_ROOT" 2>/dev/null || true
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_OUTPUT_DIR" 2>/dev/null || true
}
trap cleanup_internal EXIT

echo "🚀 Starting Harper-Kernel Foundry Smelt..."
echo "🧵 Parallelism: Using $FINAL_JOBS threads."

# 2. Prepare Source
cd "$CONTAINER_BUILD_ROOT"
# Use -q for cleaner GitHub logs
apt-get source -y "$KERNEL_SOURCE"
cd linux-*/

# 3. Dynamic Configuration Strategy
if [[ "$BASE_CONFIG" == "defconfig" || "$BASE_CONFIG" == "tinyconfig" ]]; then
    make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" "$BASE_CONFIG"
else
    cp "${CONTAINER_CONFIG_DIR}/$BASE_CONFIG" .config
    make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" olddefconfig
fi

# 4. Layer Performance Tweaks
./scripts/kconfig/merge_config.sh -m .config "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG"

# 5. Signing Cleanup & Compilation
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""

echo "🏗 Compiling Harper-Kernel..."
make ARCH="$TARGET_ARCH" \
     "$CC_TOOLCHAIN" \
     "$CROSS_CMD" \
     KDEB_SOURCENAME="$KDEB_NAME" \
     -j"$FINAL_JOBS" bindeb-pkg

# 6. Artifact Collection
mkdir -p "$CONTAINER_OUTPUT_DIR"

# Move artifacts from the build root to the output volume
# Using -f to prevent exit on missing files if some debs didn't build
mv /build/*.deb /build/*.changes /build/*.buildinfo "$CONTAINER_OUTPUT_DIR/" 2>/dev/null || true

# Collect the specific kernel binary and config
BZ_PATH=$(find arch/x86/boot/ -name bzImage | head -n 1)
[ -f "$BZ_PATH" ] && cp "$BZ_PATH" "$CONTAINER_OUTPUT_DIR/bzImage"
cp .config "$CONTAINER_OUTPUT_DIR/kernel.config"

echo "✅ Smelt Complete. (Trap will now finalize permissions)"