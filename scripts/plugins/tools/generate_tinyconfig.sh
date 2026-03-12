#!/bin/bash

genereate_tinyconfig_params() {
    cat <<EOF > "$1"
# ==============================================================================
# HARPER FOUNDRY: TINYCONFIG QUICK TEST CONFIGURATION
# ==============================================================================
# This configuration is designed for FAST pipeline testing, not production use.
# Build time: 2-5 minutes vs 30-60+ minutes for full builds.
# Use this to quickly validate changes to the foundry itself.

# ==============================================================================
# CORE FOUNDRY SETUP (Hard Requirements)
# ==============================================================================

# --- Pathing & Identity ---
# BUILD_WORKSPACE_DIR: Where compilation happens (mounted as /build)
# HOST_OUTPUT_DIR:     Where artifacts go (each build creates build_<timestamp> subdirectory)
# Note: REPO_ROOT is auto-detected
BUILD_WORKSPACE_DIR=""
HOST_OUTPUT_DIR=""

# When true, repo-relative defaults based on params file name
# When false aboslute outpaths are respected 
USE_PARAM_SCOPED_DIRS="true"

# Leave empty ("") to auto-detect the current host user's UID/GID for file ownership.
FOUNDRY_UID=""
FOUNDRY_GID=""

# Prestart config
PRE_BUILD_HOOKS=(
    "mount_tpmfs.sh"
)
POST_BUILD_HOOKS=(
    "umount_tpmfs.sh"
    "sleep.sh"
)

TPMFS_MOUNT_POINT="/tmp/tpmfs"

# --- Foundry Execution ---
# Using the tinyconfig quick test build script


# --- Foundry artifact export configuration ---
# If ARTIFCAT_DELIVERY is true, the built artifacts will be securely copied to a remote server.
# Right now SFTP and RSYNC are supported as delivery methods.
# Both require previous configuration
ARTIFACT_DELIVERY="false"
ARTIFACT_COMPRESSION="tar.gz"  # Options: "tar.gz", "zip", or "" for none
ARTIFACT_DELIVERY_METHOD="sftp"
REMOTE_DELIVERY_HOST="127.0.0.1"
REMOTE_DELIVERY_USER="debian"
REMOTE_DELIVERY_PATH="/mnt/build-data/remote-test/"
ARTIFACT_SSH_KEY=""  # Optional: Path to SSH key for authentication (if needed)
LOCAL_DELIVERY_PATH=""


# --- Foundry Image Configuration ---
DOCKERFILE_PATH="docker/docker_arm64_x86_cross_v2.dockerfile"
CONTAINER_IMAGE_NAME="debian-harper-worker"

# ==============================================================================
# TARGET KERNEL DEFINITION
# ==============================================================================

# Versioning & Tagging
BUILD_ARCH_TAG="amd64v3"
RELEASE_TAG="harper-test"

# --- Target Specifications ---
TARGET_ARCH="x86_64"
CROSS_COMPILE_PREFIX="x86_64-linux-gnu-"

# --- Kernel Source Strategy (Plugin-based) ---
# Using vanilla kernel.org for fast tinyconfig builds (no Debian patches)
KERNEL_SOURCE="kernel.org"
# Use latest LTS kernel by default (stable, long-term support)
KERNEL_VERSION="lts"
# Other options:
#   KERNEL_VERSION="latest"  # Latest stable release
#   KERNEL_VERSION="rc"      # Latest mainline/RC
#   KERNEL_VERSION="6.11.8"  # Specific version

DEB_HOST_ARCH="amd64"
HOST_QEMU_STATIC="/usr/bin/qemu-x86_64-static"

BUILD_DEB_BUILD_ARCH="arm64"
BUILD_DEB_TARGET_ARCH="amd64"
BUILD_CC="clang --target=x86_64-linux-gnu"
BUILD_HOSTLD="x86_64-linux-gnu-ld"
BUILD_HOSTCFLAGS="-I/usr/include/x86_64-linux-gnu"
BUILD_HOSTLDFLAGS="-L/usr/lib/x86_64-linux-gnu"
BUILD_LLVM="1"

# ==============================================================================
# BUILD STRATEGY & FEATURES
# ==============================================================================

# --- Performance & Parallelism ---
# Defaults to nproc-1 (min 1) when empty
# Set to "ALL" to use all available cores, or specify a number (e.g., 4)
PARALLEL_JOBS="ALL"

# --- Build Strategy ---
# Tinyconfig is a kbuild target, not a file - handles minimal kernel generation
BASE_CONFIG="tinyconfig"
# No tuning config for tinyconfig - we want absolute minimum
TUNING_CONFIG=""

# --- Patches if any ---


# ==============================================================================
# QUALITY ASSURANCE (QA) & TESTING
# ==============================================================================

# --- QA Flags ---
# For quick tests, we only do minimal validation
BYPASS_QA="false"
ENABLE_QEMU_TESTS="false"

# Use RELAXED mode - warn but don't fail on missing nice-to-haves
QA_MODE="RELAXED"

# Only run essential file validation tests
QA_TESTS=(
    "filesexists.sh"
)

# No test packages for quick builds
QA_TEST_PACKAGE=(
    
)

# --- Chemical Audit: Critical (Must Pass) ---
# For tinyconfig, we only check absolute essentials
QA_CRITICAL_CHECKS=( 
    "CONFIG_TTY=y"
    "CONFIG_PRINTK=y"
)

# --- Chemical Audit: Optional (Warn Only) ---
# Much shorter list for tinyconfig tests
QA_OPTIONAL_CHECKS=(
    "CONFIG_BLK_DEV=y"
    "CONFIG_EXT4_FS=y"
    "CONFIG_PROC_FS=y"
    "CONFIG_SYSFS=y"
)

# --- VM Proving Ground Specs (Not used for quick tests) ---
QA_VM_MEMORY="512M"
QA_VM_CORES="2"
QA_VM_TIMEOUT="15s"

# ==============================================================================
# ENVIRONMENT CUSTOMIZATION
# ==============================================================================

# --- Environment Extensions ---
# Optionally specify which environment extensions to load (in order).
# Leave empty to load none: ENV_EXTENSIONS=()
ENV_EXTENSIONS=()
EOF
}

genereate_tinyconfig_sh() {
    cat <<EOF > "$1"
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
if [[ -f "/opt/factory/scripts/env_setup.sh" ]]; then
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
if [[ -f "/opt/factory/scripts/plugins/kernelsources/runner.sh" ]]; then
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
if [[ -z "$KERNEL_DIR" ]]; then
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
if [[ -f "$BZ_PATH" ]]; then
    cp "$BZ_PATH" "$CONTAINER_OUTPUT_DIR/bzImage"
    BZ_SIZE=$(du -h "$BZ_PATH" | cut -f1)
    echo "✅ bzImage: $BZ_SIZE"
else
    echo "❌ ERROR: bzImage not found!"
    exit 1
fi

# Save config for reference
if [[ -f .config ]]; then
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

For a complete Harper kernel build, use the 'harper_deb13.sh'
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
echo "For a complete Harper kernel, use: FOUNDRY_EXEC=compile_scripts/harper_deb13.sh"
echo "(Experimental - enthusiast/hobbyist use only)"
echo ""

# Cleanup
if [[ "$INCREMENTAL_BUILD" != "true" ]]; then
    echo "🧹 Cleaning up..."
    make mrproper 2>/dev/null || true
fi
EOF
}


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
default_params_dir="${REPO_ROOT}/params"

if [[ -d "$default_params_dir" ]]; then
    echo "Found params directory: $default_params_dir"
else
    echo "❌ ERROR: Params directory not found at $default_params_dir"
    exit 1
fi
if [[ -f "$default_params_dir/tinyconfig.params" ]]; then
    echo "⚠️  Warning: $default_params_dir/tinyconfig.params already exists."
    read -p "Do you want to overwrite it? (y/N) " -n 1 -r
    echo ""
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        echo "Overwriting existing tinyconfig.params..."
        genereate_tinyconfig_params "$default_params_dir/tinyconfig.params" 
    fi
else
    echo "🛠  Generating tinyconfig.params at $default_params_dir/tinyconfig.params"
    genereate_tinyconfig_params "$default_params_dir/tinyconfig.params"
fi



