#!/bin/bash
set -e

# === CONFIGURATION ===
# Using 'defconfig' as the base for hardware compatibility
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

echo "🚀 Starting Full-Scale Harper-Kernel Pipeline..."

# 1. Prepare Source
cd "$BUILD_ROOT"
apt-get source -y "$KERNEL_SOURCE"
cd linux-*/

# 2. Baseline Configuration
echo "🏆 Generating x86_64 Defconfig Baseline..."
# We use 'defconfig' instead of 'tinyconfig' to ensure a bootable, driver-rich kernel
make ARCH="$ARCH_TARGET" "$CC_TOOLCHAIN" defconfig

# 3. Layer Performance Tweaks
echo "💉 Injecting Harper-Tuning (NTSYNC, 500Hz, ZEN3, RT)..."
./scripts/kconfig/merge_config.sh -m .config "$TUNING_FILE"

# 4. Signing & Deb-Package Prep
# Disabling signing requirements to allow local installation without custom keys
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""

# 5. Compile
echo "🏗 Compiling Harper-Kernel ($ARCH_TARGET Cross-Build)..."
# Resolve new dependencies from the merge
make ARCH="$ARCH_TARGET" "$CC_TOOLCHAIN" olddefconfig

# Build the .deb packages (this will take significantly longer than tinyconfig)
make ARCH="$ARCH_TARGET" "$CC_TOOLCHAIN" "$CROSS_CMD" -j$(nproc) bindeb-pkg

# 6. Artifact Collection
echo "📦 Collecting artifacts..."
mkdir -p "$DIST_DIR"

# A. Capture bzImage for the Proving Ground (Smoke Test)
BZ_PATH=$(find arch/x86/boot/ -name bzImage | head -n 1)
if [ -f "$BZ_PATH" ]; then
    cp "$BZ_PATH" /build/bzImage
    echo "🎯 Captured bzImage for smoke testing."
fi

# B. Capture final .config for audit
cp .config /build/kernel.config

# C. Move artifacts to the host-mounted distribution folder
if ls /build/*.deb 1> /dev/null 2>&1; then
    find /build -maxdepth 1 \( \
        -name "*.deb" -o \
        -name "*.changes" -o \
        -name "*.buildinfo" -o \
        -name "kernel.config" -o \
        -name "bzImage" \
    \) -exec mv {} "$DIST_DIR/" \;
    
    # Reclaim ownership for the host user
    chown -R "$FINAL_UID:$FINAL_GID" "$DIST_DIR"
    echo "📦 Artifacts secured in $DIST_DIR"
else
    echo "❌ ERROR: Compilation failed to produce .deb files!"
    exit 1
fi

# 7. Cleanup
echo "🧹 Cleaning up source tree..."
rm -rf "$BUILD_ROOT/linux-"*/

echo "✅ Success! Full Harper-Kernel Foundry complete."