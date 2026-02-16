#!/bin/bash
set -e

# ==============================================================================
#  HARPER ALLOY: DEBIAN 13 (TRIXIE) - ENTHUSIAST BUILD
# ==============================================================================
# Harper's primary kernel alloy, forged from Debian 13 (Trixie) backports.
# This is NOT vanilla Debian—it's a custom Harper Forge kernel with:
#   - BORE scheduler integration (with EEVDF fallback)
#   - Custom tuning profiles
#   - Complete .deb packaging
#
# ⚠️  EXPERIMENTAL - FOR ENTHUSIAST/HOBBYIST USE ONLY!
# This is a custom kernel maintained by hobbyists. Use at your own risk.
# Not recommended for production systems or mission-critical workloads.
#
# Build time: 30-60+ minutes
# Output: Complete .deb packages
# ==============================================================================
# Running as non-root 'builder' user inside container for security.
# Files are created with correct ownership matching the host user.

# 1️⃣ Load Environment
if [ -f "/opt/factory/scripts/env_setup.sh" ]; then
    source /opt/factory/scripts/env_setup.sh "$@"
else
    echo "⚠️  env_setup.sh not found. Using defaults."
    CONTAINER_BUILD_ROOT="/build"
    CONTAINER_OUTPUT_DIR="/opt/factory/output"
    CONTAINER_CONFIG_DIR="/opt/factory/configs"
    KERNEL_SOURCE="linux-source"
    TARGET_ARCH="x86_64"
    FINAL_JOBS=$(nproc)
fi

echo "🚀 Starting Harper Foundry Smelt..."
echo "🧵 Parallelism: Using $FINAL_JOBS threads."

# 2️⃣ Prepare Source
mkdir -p "$CONTAINER_BUILD_ROOT"
cd "$CONTAINER_BUILD_ROOT"

echo "📥 Fetching Kernel Source: $KERNEL_SOURCE"

# Use kernel source plugin runner to handle various source types
source "${PLUGIN_DIR}/kernelsources/runner.sh"
KERNEL_DIR=$(fetch_kernel_source "$KERNEL_SOURCE" "${KERNEL_VERSION:-latest}" "$CONTAINER_BUILD_ROOT" | tail -n1)
cd "$KERNEL_DIR" || { echo "❌ ERROR: Failed to fetch or locate kernel source"; exit 1; }

# 3️⃣ Apply BORE/EEVDF Patch
source "${PLUGIN_DIR}/patches/bore.sh"

#Checking directory contents for debugging
echo "🔍 Current directory contents:"
pwd
ls -lhta

# 4️⃣ Initialize Pristine .config
echo "🛠 Generating fresh default Debian config..."
rm -f .config  # ⬅️ Force wipe any stale state from previous runs
env -u ARCH CC=x86_64-linux-gnu-gcc dpkg-architecture -a amd64 -c debian/rules source
env -u ARCH CC=x86_64-linux-gnu-gcc dpkg-architecture -a amd64 -c fakeroot make -f debian/rules.gen setup_amd64_none_amd64
cp debian/build/build_amd64_none_amd64/.config .config

# 5️⃣ Merge Tuning Profile
if [ -f "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG" ]; then
    echo "🧪 Merging Tuning Profile: $TUNING_CONFIG"
    cp "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG" ./
    
    # Executing WITHOUT -m, and explicitly passing LLVM and ARCH 
    # to protect the toolchain variables during validation
    LLVM=1 ARCH="$TARGET_ARCH" ./scripts/kconfig/merge_config.sh .config "$TUNING_CONFIG"
fi

# 6️⃣ Sanitization (Keys, Debug)
echo "🧹 Stripping Keys / Debug Options..."
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str SYSTEM_TRUSTED_KEYS ""
./scripts/config --set-str SYSTEM_REVOCATION_KEYS ""

# 🔑 The fix for the certs/signing_key.x509 crash
./scripts/config --set-str MODULE_SIG_KEY ""

# Protect the environment variables during this final dependency check
make LLVM="$BUILD_LLVM" ARCH="$TARGET_ARCH" olddefconfig

# 7️⃣ Versioning
TIMESTAMP=$(date +%Y%m%d%M)
KERNEL_VER=$(make -s kernelversion)

# SCHED_PRIORITY is now set by the BORE patch plugin
export LOCALVERSION="-${PROJECT}-${BUILD_ARCH_TAG}-${SCHEDULER_LABEL}"
export KDEB_PKGVERSION="${KERNEL_VER}-${PROJECT}.${SCHED_PRIORITY}.${TIMESTAMP}"

echo "🏷️  Kernel Release (uname -r): ${KERNEL_VER}${LOCALVERSION}"
echo "📦 Debian Pkg Version (apt):  ${KDEB_PKGVERSION}"

# 8️⃣ Compile Kernel with LLVM
echo "🏗️ Compiling Kernel..."
make -j"$FINAL_JOBS" \
    LLVM="$BUILD_LLVM" \
    ARCH="$TARGET_ARCH" \
    CROSS_COMPILE="$CROSS_COMPILE_PREFIX" \
    KBUILD_BUILD_ARCH="$TARGET_ARCH" \
    DEB_BUILD_ARCH="$BUILD_DEB_BUILD_ARCH" \
    DEB_TARGET_ARCH="$BUILD_DEB_TARGET_ARCH" \
    KBUILD_DEBARCH="$BUILD_DEB_TARGET_ARCH" \
    CC="$BUILD_CC" \
    HOSTCC="$BUILD_CC" \
    HOSTLD="$BUILD_HOSTLD" \
    HOSTCFLAGS="$BUILD_HOSTCFLAGS" \
    HOSTLDFLAGS="$BUILD_HOSTLDFLAGS" \
    KERNEL_CFLAGS="$KERNEL_CFLAGS" \
    LOCALVERSION="$LOCALVERSION" \
    KDEB_PKGVERSION="$KDEB_PKGVERSION" \
    bindeb-pkg


# 9️⃣ Collect Artifacts
echo "📦 Collecting artifacts..."
mkdir -p "$CONTAINER_OUTPUT_DIR"
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.deb" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.changes" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.buildinfo" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +


BZ_PATH=$(find . -name bzImage | head -n1)
[ -f "$BZ_PATH" ] && cp "$BZ_PATH" "$CONTAINER_OUTPUT_DIR/bzImage"
[ -f .config ] && cp .config "$CONTAINER_OUTPUT_DIR/kernel.config"

echo "✅ Harper Kernel Build Complete."

# Guarantee a completely sterile environment before patching or configuring
if [ "$INCREMENTAL_BUILD" != "true" ]; then
    echo "🧹 Scrubbing source tree to factory-fresh state..."
    make mrproper
fi