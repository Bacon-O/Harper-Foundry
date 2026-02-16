#!/bin/bash
set -e

# ==============================================================================
#  HARPER FOUNDRY: TINYCONFIG QUICK TEST BUILD
# ==============================================================================
# This is a minimal, fast build for testing the foundry pipeline.
# It uses tinyconfig (absolute minimum kernel) for speed.
# Typical build time: 2-5 minutes vs 30-60+ minutes for full build.
# Running as non-root 'builder' user inside container for security.

# Standardized container internal paths (constants defined by the Docker image)
readonly CONTAINER_BUILD_ROOT="/build"
readonly CONTAINER_OUTPUT_DIR="/opt/factory/output"

# 1️⃣ Load Environment
if [ -f "/opt/factory/scripts/env_setup.sh" ]; then
    source /opt/factory/scripts/env_setup.sh "$@"
else
    echo "⚠️  env_setup.sh not found. Using defaults."
    TARGET_ARCH="x86_64"
    FINAL_JOBS=$(nproc)
fi

echo "🧵 Harper Foundry: TINYCONFIG Quick Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚡ Fast build mode: Minimal kernel for pipeline testing"
echo "🧵 Parallelism: Using $FINAL_JOBS threads."
echo ""

# 2️⃣ Load Kernel Source Plugin System
# This allows flexible kernel source handling (kernel.org, debian, custom, etc.)
if [ -f "/opt/factory/scripts/plugins/kernelsources/runner.sh" ]; then
    source /opt/factory/scripts/plugins/kernelsources/runner.sh
else
    echo "⚠️  WARNING: kernel source plugin system not found"
    echo "⚠️  This build requires KERNEL_SOURCE and KERNEL_VERSION to be set via params"
fi

# 3️⃣ Fetch Kernel Source
# The plugin system handles mapping KERNEL_SOURCE parameter to appropriate fetching method
mkdir -p "$CONTAINER_BUILD_ROOT"
cd "$CONTAINER_BUILD_ROOT"

echo "📥 Fetching kernel source via plugin: KERNEL_SOURCE=$KERNEL_SOURCE"
fetch_kernel_source "$KERNEL_SOURCE" "$KERNEL_VERSION" "$CONTAINER_BUILD_ROOT" >/dev/null
KERNEL_DIR=$(find "$CONTAINER_BUILD_ROOT" -maxdepth 1 -type d -name "linux-*" | head -n1)
if [ -z "$KERNEL_DIR" ]; then
    echo "❌ ERROR: Failed to fetch kernel via plugin"
    exit 1
fi

echo "📦 Kernel source ready: $KERNEL_DIR"
cd "$KERNEL_DIR" || { echo "❌ ERROR: Failed to enter kernel directory"; exit 1; }

# 4️⃣ Initialize Minimal Config
echo "🛠 Generating tinyconfig (absolute minimum)..."
rm -f .config
rm -f arch/*/configs/.config 2>/dev/null || true

# Use tinyconfig for the fastest possible build
make LLVM="$BUILD_LLVM" ARCH="$TARGET_ARCH" tinyconfig

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

# Finalize config - use yes to auto-answer prompts with defaults
echo "🔧 Finalizing minimal config (auto-accepting defaults)..."
yes "" | make LLVM="$BUILD_LLVM" ARCH="$TARGET_ARCH" oldconfig 2>/dev/null || true

# 7️⃣ Versioning
TIMESTAMP=$(date +%Y%m%d%H%M)
KERNEL_VER=$(make -s kernelversion)

export LOCALVERSION="-${RELEASE_TAG}-${BUILD_ARCH_TAG}-tinytest"
export KDEB_PKGVERSION="${KERNEL_VER}-${RELEASE_TAG}.test.${TIMESTAMP}"

echo "🏷️  Kernel Release (uname -r): ${KERNEL_VER}${LOCALVERSION}"
echo "📦 Debian Pkg Version (apt):  ${KDEB_PKGVERSION}"
echo ""

# 8️⃣ Compile Kernel (Just bzImage, no modules for speed)
echo "🏗️ Compiling Minimal Kernel..."
echo "⚡ Building bzImage only (no modules, no packages) for max speed..."
time make -j"$FINAL_JOBS" \
    LLVM="$BUILD_LLVM" \
    ARCH="$TARGET_ARCH" \
    CROSS_COMPILE="$CROSS_COMPILE_PREFIX" \
    CC="$BUILD_CC" \
    HOSTCC="$BUILD_CC" \
    HOSTLD="$BUILD_HOSTLD" \
    HOSTCFLAGS="$BUILD_HOSTCFLAGS" \
    HOSTLDFLAGS="$BUILD_HOSTLDFLAGS" \
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
Harper Foundry - Tinyconfig Test Build
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

For a complete Harper kernel build, use the 'harper_deb13..sh' alloy
mixture (still experimental—for enthusiast/hobbyist use).
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
echo "For a complete Harper kernel, use: FOUNDRY_EXEC=alloymixtures/harper_deb13..sh"
echo "(Experimental - enthusiast/hobbyist use only)"
echo ""

# Cleanup
if [ "$INCREMENTAL_BUILD" != "true" ]; then
    echo "🧹 Cleaning up..."
    make mrproper 2>/dev/null || true
fi
