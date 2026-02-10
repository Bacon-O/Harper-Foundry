#!/bin/bash
set -e

# === CONFIGURATION ===
# Internal Container Paths
TUNING_FILE="/opt/factory/configs/harper_tunes.config"
BUILD_ROOT="/build"
DIST_DIR="/opt/factory/dist"

# Build Parameters
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

# 2. Baseline
echo "🐣 Generating fresh tiny baseline..."
make ARCH="$ARCH_TARGET" "$CC_TOOLCHAIN" tinyconfig

# 3. Layer Tweaks
echo "🔥 Merging Harper Tuning tweaks (NTSYNC/Zen3)..."
./scripts/kconfig/merge_config.sh -m .config "$TUNING_FILE"

# 4. Signing Cleanup
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""

# 5. Compile
echo "🏗 Compiling Harper-Kernel ($ARCH_TARGET Cross-Build)..."
make ARCH="$ARCH_TARGET" "$CC_TOOLCHAIN" olddefconfig
make ARCH="$ARCH_TARGET" \
     "$CC_TOOLCHAIN" \
     "$CROSS_CMD" \
     -j$(nproc) bindeb-pkg

# 6. Artifact Collection
echo "📦 Collecting artifacts..."
mkdir -p "$DIST_DIR"

if ls /build/*.deb 1> /dev/null 2>&1; then
    find /build -maxdepth 1 \( -name "*.deb" -o -name "*.changes" -o -name "*.buildinfo" \) -exec mv {} "$DIST_DIR/" \;
    
    # Apply dynamic permissions
    chown -R "$FINAL_UID:$FINAL_GID" "$DIST_DIR"
    echo "📦 Artifacts secured in $DIST_DIR"
else
    echo "❌ ERROR: No .deb files found in /build!"
    exit 1
fi

# 7. Cleanup
echo "🧹 Cleaning up source tree..."
rm -rf "$BUILD_ROOT/linux-"*/

echo "✅ Success! Build complete."