#!/bin/bash
set -e

# 1. Load Fuel (Handles params + identity)
source /opt/factory/scripts/env_setup.sh

echo "🚀 Starting Harper-Kernel Foundry Smelt..."
echo "🛠 Strategy: Base ($BASE_CONFIG) + Tuning ($TUNING_CONFIG)"
echo "🧵 Parallelism: Using $FINAL_JOBS threads."

# 2. Prepare Source
cd "$CONTAINER_BUILD_ROOT"
apt-get source -y "$KERNEL_SOURCE"
cd linux-*/

# 3. Dynamic Configuration Strategy
if [[ "$BASE_CONFIG" == "defconfig" || "$BASE_CONFIG" == "tinyconfig" ]]; then
    echo "🐣 Using standard Kbuild target: $BASE_CONFIG"
    make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" "$BASE_CONFIG"
else
    echo "📄 Using custom base file: $BASE_CONFIG"
    cp "${CONTAINER_CONFIG_DIR}/$BASE_CONFIG" .config
    make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" olddefconfig
fi

# 4. Layer Performance Tweaks
echo "💉 Injecting Harper-Tuning from $TUNING_CONFIG..."
./scripts/kconfig/merge_config.sh -m .config "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG"

# 5. Signing Cleanup & Compilation
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""

echo "🏗 Compiling Harper-Kernel ($TARGET_ARCH Cross-Build)..."
# Using FINAL_JOBS calculated in env_setup
make ARCH="$TARGET_ARCH" \
     "$CC_TOOLCHAIN" \
     "$CROSS_CMD" \
     KDEB_SOURCENAME="$KDEB_NAME" \
     -j"$FINAL_JOBS" bindeb-pkg

# 6. Artifact Collection
echo "📦 Collecting artifacts into $CONTAINER_OUTPUT_DIR..."
mkdir -p "$CONTAINER_OUTPUT_DIR"

BZ_PATH=$(find arch/x86/boot/ -name bzImage | head -n 1)
[ -f "$BZ_PATH" ] && cp "$BZ_PATH" /build/bzImage
cp .config /build/kernel.config

# Move artifacts to output volume
find /build -maxdepth 1 \( -name "*.deb" -o -name "*.changes" -o -name "*.buildinfo" -o -name "kernel.config" -o -name "bzImage" \) -exec mv {} "$CONTAINER_OUTPUT_DIR/" \;

# Final Ownership Fix
chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_OUTPUT_DIR"
echo "✅ Smelt Complete."