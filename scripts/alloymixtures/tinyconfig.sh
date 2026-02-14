#!/bin/bash
set -e

# ==============================================================================
#  HARPER-KERNEL FOUNDRY: TINYCONFIG QUICK TEST BUILD
# ==============================================================================
# This is a minimal, fast build for testing the foundry pipeline.
# It uses tinyconfig (absolute minimum kernel) for speed.
# Typical build time: 2-5 minutes vs 30-60+ minutes for full build.

# 1️⃣ Load Environment
if [ -f "/opt/factory/scripts/env_setup.sh" ]; then
    source /opt/factory/scripts/env_setup.sh "$@"
else
    echo "⚠️  env_setup.sh not found. Using defaults."
    HOST_UID=${HOST_UID:-1000}
    HOST_GID=${HOST_GID:-1000}
    CONTAINER_BUILD_ROOT="/build"
    CONTAINER_OUTPUT_DIR="/opt/factory/output"
    TARGET_ARCH="x86_64"
    FINAL_JOBS=$(nproc)
fi

# 2️⃣ Cleanup Trap
cleanup_internal() {
    echo "⚖️ Reclaiming ownership for host user $HOST_UID..."
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_BUILD_ROOT" 2>/dev/null || true
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_OUTPUT_DIR" 2>/dev/null || true
}
trap cleanup_internal EXIT

echo "🧪 Harper-Kernel Foundry: TINYCONFIG Quick Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚡ Fast build mode: Minimal kernel for pipeline testing"
echo "🧵 Parallelism: Using $FINAL_JOBS threads."
echo ""

# 3️⃣ Prepare Source
mkdir -p "$CONTAINER_BUILD_ROOT"
cd "$CONTAINER_BUILD_ROOT"

echo "📥 Fetching Kernel Source: $KERNEL_SOURCE"
apt-get source -y "$KERNEL_SOURCE"
cd linux-*/ || { echo "❌ ERROR: Kernel source not found"; exit 1; }

# 4️⃣ Initialize Minimal Config
echo "🛠 Generating tinyconfig (absolute minimum)..."
rm -f .config

# Use tinyconfig for the fastest possible build
make LLVM="$MAKE_LLVM" ARCH="$TARGET_ARCH" tinyconfig

# 5️⃣ Essential Tweaks for Bootability (Optional)
# Tinyconfig is TOO minimal - add bare essentials for a bootable kernel
echo "🔧 Enabling minimal bootable features..."
./scripts/config --enable TTY
./scripts/config --enable PRINTK
./scripts/config --enable BLK_DEV
./scripts/config --enable EXT4_FS
./scripts/config --enable PROC_FS
./scripts/config --enable SYSFS

# 6️⃣ Sanitization (Keys)
echo "🧹 Stripping Keys..."
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str SYSTEM_TRUSTED_KEYS ""
./scripts/config --set-str SYSTEM_REVOCATION_KEYS ""
./scripts/config --set-str MODULE_SIG_KEY ""

# Finalize config
make LLVM="$MAKE_LLVM" ARCH="$TARGET_ARCH" olddefconfig

# 7️⃣ Versioning
TIMESTAMP=$(date +%Y%m%d%H%M)
KERNEL_VER=$(make -s kernelversion)

export LOCALVERSION="-${PROJECT_TAG}-${ARCH_TAG}-tinytest"
export KDEB_PKGVERSION="${KERNEL_VER}-${PROJECT_TAG}.test.${TIMESTAMP}"

echo "🏷️  Kernel Release (uname -r): ${KERNEL_VER}${LOCALVERSION}"
echo "📦 Debian Pkg Version (apt):  ${KDEB_PKGVERSION}"
echo ""

# 8️⃣ Compile Kernel (Just bzImage, no modules for speed)
echo "🏗️ Compiling Minimal Kernel..."
echo "⚡ Building bzImage only (no modules, no packages) for max speed..."
time make -j"$FINAL_JOBS" \
    LLVM="$MAKE_LLVM" \
    ARCH="$TARGET_ARCH" \
    CROSS_COMPILE="$CROSS_CMD" \
    CC="$MAKE_CC" \
    HOSTCC="$MAKE_CC" \
    HOSTLD="$MAKE_HOSTLD" \
    HOSTCFLAGS="$MAKE_HOSTCFLAGS" \
    HOSTLDFLAGS="$MAKE_HOSTLDFLAGS" \
    LOCALVERSION="$LOCALVERSION" \
    bzImage

echo ""
echo "✅ bzImage compilation complete!"
echo ""

# 9️⃣ Collect Artifacts
echo "📦 Collecting test artifacts..."
mkdir -p "$CONTAINER_OUTPUT_DIR"

# Find and copy bzImage
BZ_PATH=$(find . -name bzImage | head -n1)
if [ -f "$BZ_PATH" ]; then
    cp "$BZ_PATH" "$CONTAINER_OUTPUT_DIR/bzImage"
    BZ_SIZE=$(du -h "$BZ_PATH" | cut -f1)
    echo "✅ bzImage: $BZ_SIZE"
else
    echo "❌ ERROR: bzImage not found!"
    exit 1
fi

# Save config for reference
if [ -f .config ]; then
    cp .config "$CONTAINER_OUTPUT_DIR/kernel.config"
    echo "✅ Config saved"
fi

# Create a marker file indicating this was a test build
cat > "$CONTAINER_OUTPUT_DIR/BUILD_INFO.txt" << EOF
Harper Kernel Foundry - Tinyconfig Test Build
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Build Type: TINYCONFIG QUICK TEST
Timestamp: $(date)
Kernel Version: ${KERNEL_VER}${LOCALVERSION}
Target Arch: $TARGET_ARCH
Build Duration: See timestamps above
Purpose: Pipeline/Foundry testing only
Status: NOT FOR PRODUCTION USE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
This is a minimal test build to validate the foundry
pipeline. It contains only the bare minimum kernel
features and should NOT be used in production.

For a full production build, use the 'full.sh' alloy
mixture instead.
EOF

echo "✅ Build info saved"
echo ""

# 🔟 Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Tinyconfig Test Build Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚡ This was a FAST test build - not suitable for production!"
echo "📂 Artifacts in: $CONTAINER_OUTPUT_DIR"
echo ""
echo "What was tested:"
echo "  ✅ Foundry environment setup"
echo "  ✅ Kernel source fetching"
echo "  ✅ Build toolchain"
echo "  ✅ Compilation process"
echo "  ✅ Artifact collection"
echo ""
echo "For a full production build, use: FOUNDRY_EXEC=alloymixtures/full.sh"
echo ""

# Cleanup
if [ "$INCREMENTAL_BUILD" != "true" ]; then
    echo "🧹 Cleaning up..."
    make mrproper 2>/dev/null || true
fi
