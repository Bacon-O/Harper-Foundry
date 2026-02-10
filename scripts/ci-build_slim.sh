#!/bin/bash
set -e

# === CONFIGURATION ===
TUNING_FILE="/opt/factory/configs/harper_tunes.config"
BUILD_ROOT="/build"
DIST_DIR="/opt/factory/dist"
KERNEL_SOURCE="linux/trixie-backports"
ARCH_TARGET="x86_64"
CC_TOOLCHAIN="LLVM=1"
CROSS_CMD="CROSS_COMPILE=x86_64-linux-gnu-"

# Permission Identity (Injected from Host)
FINAL_UID=${HOST_UID:-0}
FINAL_GID=${HOST_GID:-0}
# =====================

echo "🚀 Starting Dynamic Harper-Kernel Pipeline..."

# 1. Prepare Source
cd "$BUILD_ROOT"
apt-get source -y "$KERNEL_SOURCE"
cd linux-*/

# 2. Baseline & Layer Tweaks
echo "🐣 Generating tiny baseline & merging tweaks..."
make ARCH="$ARCH_TARGET" "$CC_TOOLCHAIN" tinyconfig
./scripts/kconfig/merge_config.sh -m .config "$TUNING_FILE"

# 3. Signing Cleanup
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""

# 4. Compile
echo "🏗 Compiling Harper-Kernel ($ARCH_TARGET Cross-Build)..."
make ARCH="$ARCH_TARGET" "$CC_TOOLCHAIN" olddefconfig
make ARCH="$ARCH_TARGET" "$CC_TOOLCHAIN" "$CROSS_CMD" -j$(nproc) bindeb-pkg

# 5. Artifact Collection
echo "📦 Collecting artifacts..."
mkdir -p "$DIST_DIR"

# A. Rescue the bzImage from the source tree before we delete it
BZ_PATH=$(find arch/x86/boot/ -name bzImage | head -n 1)
if [ -f "$BZ_PATH" ]; then
    cp "$BZ_PATH" /build/bzImage
    echo "🎯 Captured bzImage for smoke testing."
else
    echo "⚠️ Warning: bzImage not found in arch/x86/boot/"
fi

# B. Capture the final .config for the audit script to read
cp .config /build/kernel.config

# C. Move everything from /build to the timestamped dist folder
if ls /build/*.deb 1> /dev/null 2>&1; then
    find /build -maxdepth 1 \( \
        -name "*.deb" -o \
        -name "*.changes" -o \
        -name "*.buildinfo" -o \
        -name "kernel.config" -o \
        -name "bzImage" \
    \) -exec mv {} "$DIST_DIR/" \;
    
    # Fix permissions for the OCI host user
    chown -R "$FINAL_UID:$FINAL_GID" "$DIST_DIR"
    echo "📦 Artifacts secured in $DIST_DIR"
else
    echo "❌ ERROR: No .deb files found!"
    exit 1
fi

# 6. Cleanup
echo "🧹 Cleaning up source tree..."
rm -rf "$BUILD_ROOT/linux-"*/

echo "✅ Success! Foundry complete."