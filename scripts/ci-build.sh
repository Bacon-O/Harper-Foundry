#!/bin/bash
set -e

# 1. Load Fuel (Handles params + identity)
# Sourcing this inside the container ensures we have CONTAINER_OUTPUT_DIR and HOST_UID
source /opt/factory/scripts/env_setup.sh

# --- The "Hand-off" Trap ---
cleanup_internal() {
    echo "⚖️ Internal Fix: Reclaiming ownership for Host UID: $HOST_UID"
    # Reclaim everything in the build root AND the output dir
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_BUILD_ROOT" 2>/dev/null || true
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_OUTPUT_DIR" 2>/dev/null || true
}
trap cleanup_internal EXIT

echo "🚀 Starting Harper-Kernel Foundry Smelt..."
echo "🧵 Parallelism: Using $FINAL_JOBS threads."

echo "🔧 Verifying packaging tools..."
apt-get update && apt-get install -y rsync
apt-get update && apt-get install -y rsync llvm

# 2. Prepare Source
cd "$CONTAINER_BUILD_ROOT"
echo "📥 Fetching Source: $KERNEL_SOURCE"
apt-get source -y "$KERNEL_SOURCE"

# Navigate to the source directory (Assumes only one folder matches linux-*)
cd linux-*/ || { echo "❌ ERROR: Source directory not found!"; exit 1; }

# --- 2.5. Inject Patches (BORE Scheduler) ---
# We do this BEFORE config generation to ensure Kconfig is aware of new symbols.
echo "💉 Injecting BORE Scheduler..."

# Define the Patch URL (Verify this version matches your kernel version!)
echo "   Fetching patch from: $BORE_PATCH_URL"

# --- 2.5. Inject Patches ---
if [ -n "$BORE_PATCH_URL" ]; then
    echo "💉 Injecting Patch: $BORE_PATCH_URL"
    if curl -fLo bore.patch "$BORE_PATCH_URL"; then
        # Apply with fuzz factor 3 to handle minor offsets
        if patch -p1 -F 3 < bore.patch; then
            echo "   ✅ Patch applied successfully."
        else
            echo "   ❌ ERROR: Patch application failed!"
            exit 1
        fi
    else
        echo "   ❌ ERROR: Download failed."
        exit 1
    fi
else
    echo "⏩ No patch URL defined. Skipping injection."
fi

# 3. Base Configuration Strategy
if [[ "$BASE_CONFIG" == "defconfig" || "$BASE_CONFIG" == "tinyconfig" ]]; then
    echo "🐣 Applying base: $BASE_CONFIG"
    make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" "$BASE_CONFIG"
else
    echo "📄 Applying custom base: $BASE_CONFIG"
    cp "${CONTAINER_CONFIG_DIR}/$BASE_CONFIG" .config
    make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" olddefconfig
fi

# 4. Layer Performance Tweaks (RT + NTSYNC + Tunes)
echo "🧪 Merging Tuning: $TUNING_CONFIG"
./scripts/kconfig/merge_config.sh -m .config "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG"

# 5. Config Sanitization & Interactive-Gate
echo "🧹 Stripping Keys and Finalizing Config..."
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""

# REQUIRED: Seal the config to resolve new dependencies non-interactively.
# This fixes the "Error in reading or end of file" loop.
make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" olddefconfig

echo "🏗 Compiling Harper-Kernel ($TARGET_ARCH)..."
# We inject KDEB_SOURCENAME to ensure the .deb files have your custom name
make ARCH="$TARGET_ARCH" \
     $CC_TOOLCHAIN \
     "$CROSS_CMD" \
     KCFLAGS="$USER_KCFLAGS" \
     KDEB_SOURCENAME="$KDEB_NAME" \
     -j"$FINAL_JOBS" bindeb-pkg

# 6. Artifact Collection (The Directory Fix)
# Ensure the internal mount point exists
mkdir -p "$CONTAINER_OUTPUT_DIR"

echo "📦 Exporting artifacts to host volume: $CONTAINER_OUTPUT_DIR"

# Move the Debian packages. Note: bindeb-pkg places them in the parent of the source tree.
# We look in CONTAINER_BUILD_ROOT (which is /build)
# Using 'mv -f' to force overwrite if artifacts exist from a previous failed run
mv -f "$CONTAINER_BUILD_ROOT"/*.deb \
      "$CONTAINER_BUILD_ROOT"/*.changes \
      "$CONTAINER_BUILD_ROOT"/*.buildinfo \
      "$CONTAINER_OUTPUT_DIR/" 2>/dev/null || true

# Collect the specific kernel binary
BZ_PATH=$(find arch/x86/boot/ -name bzImage | head -n 1)
if [ -f "$BZ_PATH" ]; then
    cp "$BZ_PATH" "$CONTAINER_OUTPUT_DIR/bzImage"
    echo "🎯 bzImage captured."
else
    echo "⚠️ bzImage not found!"
fi

# Save the final config for the Analysis Audit
cp .config "$CONTAINER_OUTPUT_DIR/kernel.config"

echo "✅ Smelt Complete."