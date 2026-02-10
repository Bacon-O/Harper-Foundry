#!/bin/bash
set -e

# These paths match the 'docker run' mounts exactly
CONFIG_FILE="/opt/factory/configs/harper_tunes.config"
BUILD_ROOT="/build"

echo "🛠 Starting Harper-Kernel Slim CI Build..."

# 1. Get Source
cd "$BUILD_ROOT"
apt-get source linux/trixie-backports
cd linux-*/

# 2. Baseline
make ARCH=x86_64 LLVM=1 tinyconfig

# 3. Apply Tunes using the ABSOLUTE path
# This fixes the 'file does not exist' error
./scripts/kconfig/merge_config.sh -m .config "$CONFIG_FILE"

# 4. Clean up signing for OCI
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""

# 5. Finalize and Cross-Compile
make ARCH=x86_64 LLVM=1 olddefconfig
make ARCH=x86_64 \
     LLVM=1 \
     CROSS_COMPILE=x86_64-linux-gnu- \
     -j$(nproc) bindeb-pkg

echo "✅ Success! Check ${BUILD_ROOT} for your .deb files."