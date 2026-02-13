#!/bin/bash
set -e

# ==============================================================================
#  HARPER-KERNEL FOUNDRY: CI BUILD SCRIPT
# ==============================================================================

# 1️⃣ Load Environment
if [ -f "/opt/factory/scripts/env_setup.sh" ]; then
    source /opt/factory/scripts/env_setup.sh "$@"
else
    echo "⚠️  env_setup.sh not found. Using defaults."
    HOST_UID=${HOST_UID:-1000}
    HOST_GID=${HOST_GID:-1000}
    CONTAINER_BUILD_ROOT="/build"
    CONTAINER_OUTPUT_DIR="/opt/factory/output"
    CONTAINER_CONFIG_DIR="/opt/factory/configs"
    KERNEL_SOURCE="linux-source"
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

echo "🚀 Starting Harper-Kernel Foundry Smelt..."
echo "🧵 Parallelism: Using $FINAL_JOBS threads."

# 3️⃣ Prepare Source
mkdir -p "$CONTAINER_BUILD_ROOT"
cd "$CONTAINER_BUILD_ROOT"

echo "📥 Fetching Kernel Source: $KERNEL_SOURCE"
apt-get source -y "$KERNEL_SOURCE"
cd linux-*/ || { echo "❌ ERROR: Kernel source not found"; exit 1; }

# 4️⃣ Apply BORE/EEVDF Patch
SCHEDULER_LABEL="eevdf"
if [ -n "$BORE_PATCH_URL" ]; then
    echo "💉 Applying Scheduler Patch..."
    if curl -fLo bore.patch "$BORE_PATCH_URL"; then
        if patch -p1 -F3 < bore.patch; then
            echo "✅ BORE patch applied."
            SCHEDULER_LABEL="bore"
        else
            echo "⚠️ Patch failed. Using fallback EEVDF scheduler."
        fi
    fi
fi

# 5️⃣ Initialize .config
if [ ! -f .config ]; then
    echo "🛠 Initializing default config..."
    make defconfig
fi

# 6️⃣ Merge Tuning Profile
if [ -f "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG" ]; then
    echo "🧪 Merging Tuning Profile: $TUNING_CONFIG"
    cp "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG" ./
    ./scripts/kconfig/merge_config.sh -m .config "$TUNING_CONFIG"
fi

# Resolve dependencies
make olddefconfig

# 8️⃣ Sanitization (Keys, Debug)
echo "🧹 Stripping Keys / Debug Options..."
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
make olddefconfig

# 9️⃣ Versioning
if [ -f "debian/changelog" ]; then
    OFFICIAL_VER=$(dpkg-parsechangelog -S Version)
else
    OFFICIAL_VER=$(make -s kernelversion)
fi
TIMESTAMP=$(date +%Y%m%d)
SCHED_PRIORITY=$([ "$SCHEDULER_LABEL" == "bore" ] && echo "200" || echo "100")
PKG_VERSION="${OFFICIAL_VER}+harper.${SCHED_PRIORITY}.${SCHEDULER_LABEL}.${TIMESTAMP}"
echo "🏷️ Harper Kernel Version: $PKG_VERSION"

# 🔟 Clean Build Artifacts (if not incremental)
if [ "$INCREMENTAL_BUILD" != "true" ]; then
    echo "🧹 Cleaning previous build artifacts..."
    make clean
fi

# 1️⃣1️⃣ Compile Kernel with LLVM
echo "🏗️ Compiling Kernel..."
make -j$(nproc) \
    LLVM=1 \
    ARCH="$TARGET_ARCH" \
    CROSS_COMPILE="$CROSS_CMD" \
    KBUILD_BUILD_ARCH="$TARGET_ARCH" \
    DEB_BUILD_ARCH="$MAKE_DEB_BUILD_ARCH" \
    DEB_TARGET_ARCH="$MAKE_DEB_TARGET_ARCH" \
    KBUILD_DEBARCH="$MAKE_DEB_TARGET_ARCH" \
    CC="$MAKE_CC" \
    HOSTCC="$MAKE_CC" \
    HOSTLD="$MAKE_HOSTLD" \
    HOSTCFLAGS="$MAKE_HOSTCFLAGS" \
    HOSTLDFLAGS="$MAKE_HOSTLDFLAGS" \
    USER_KCFLAGS="$USER_KCFLAGS" \
    bindeb-pkg

# 1️⃣2️⃣ Collect Artifacts
echo "📦 Collecting artifacts..."
mkdir -p "$CONTAINER_OUTPUT_DIR"
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.deb" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.changes" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.buildinfo" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +

BZ_PATH=$(find . -name bzImage | head -n1)
[ -f "$BZ_PATH" ] && cp "$BZ_PATH" "$CONTAINER_OUTPUT_DIR/bzImage"
[ -f .config ] && cp .config "$CONTAINER_OUTPUT_DIR/kernel.config"

echo "✅ Harper Kernel Build Complete."
