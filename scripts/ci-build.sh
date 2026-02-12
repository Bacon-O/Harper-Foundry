#!/bin/bash
set -e

# ==============================================================================
#  HARPER-KERNEL FOUNDRY: MAIN SMELTING SCRIPT
#  "The heat of the forge reveals the strength of the steel."
# ==============================================================================

# 1. Load Fuel (Environment Variables)
if [ -f "/opt/factory/scripts/env_setup.sh" ]; then
    source /opt/factory/scripts/env_setup.sh
else
    echo "⚠️  Warning: env_setup.sh not found. Using local defaults."
    HOST_UID=${HOST_UID:-1000}
    HOST_GID=${HOST_GID:-1000}
    CONTAINER_BUILD_ROOT="/build"
    CONTAINER_OUTPUT_DIR="/opt/factory/output"
    CONTAINER_CONFIG_DIR="/opt/factory/configs"
    KERNEL_SOURCE="linux-source"
    TARGET_ARCH="x86_64"
    FINAL_JOBS=$(nproc)
fi

# --- Cleanup Trap ---
cleanup_internal() {
    echo "⚖️  Internal Fix: Reclaiming ownership for Host UID: $HOST_UID"
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_BUILD_ROOT" 2>/dev/null || true
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_OUTPUT_DIR" 2>/dev/null || true
}
trap cleanup_internal EXIT

echo "🚀 Starting Harper-Kernel Foundry Smelt..."
echo "🧵 Parallelism: Using $FINAL_JOBS threads."

HOST_ARCH=$(uname -m)

# --- Auto-Detect Architecture & Pkg-Config ---
if [ "$HOST_ARCH" != "x86_64" ] && [ "$TARGET_ARCH" == "x86_64" ]; then
    echo "🔧 Cross-Compiling Detected ($HOST_ARCH -> $TARGET_ARCH)"
    PKG_CONFIG_TOOL="x86_64-linux-gnu-pkg-config"
else
    echo "🔧 Native Build Detected ($HOST_ARCH)"
    PKG_CONFIG_TOOL="pkg-config"
fi

# 2. Prepare Source
echo "🔧 Verifying packaging tools..."
apt-get update && apt-get install -y rsync llvm curl patch

mkdir -p "$CONTAINER_BUILD_ROOT"
cd "$CONTAINER_BUILD_ROOT"

echo "📥 Fetching Source: $KERNEL_SOURCE"
apt-get source -y "$KERNEL_SOURCE"
cd linux-*/ || { echo "❌ ERROR: Source directory not found!"; exit 1; }

# --- 2.5. Inject Patches (BORE Scheduler) ---
echo "💉 Injecting Custom Scheduler..."
SCHEDULER_LABEL="eevdf"

if [ -n "$BORE_PATCH_URL" ]; then
    echo "   Fetching patch from: $BORE_PATCH_URL"
    if curl -fLo bore.patch "$BORE_PATCH_URL"; then
        if patch -p1 -F 3 < bore.patch; then
            echo "   ✅ Patch applied successfully."
            SCHEDULER_LABEL="bore"
        else
            echo "   ⚠️  Patch failed! Falling back to standard EEVDF."
        fi
    fi
fi

# 3. Base Configuration
# Using standard LLVM=1 flow
if [[ "$BASE_CONFIG" == "defconfig" || "$BASE_CONFIG" == "tinyconfig" ]]; then
    echo "🐣 Applying standard base: $BASE_CONFIG"
    make ARCH="$TARGET_ARCH" LLVM=1 "$BASE_CONFIG"
else
    echo "📄 Applying custom base: $BASE_CONFIG"
    if [ -f "${CONTAINER_CONFIG_DIR}/$BASE_CONFIG" ]; then
        cp "${CONTAINER_CONFIG_DIR}/$BASE_CONFIG" .config
        make ARCH="$TARGET_ARCH" LLVM=1 olddefconfig
    else
        echo "❌ ERROR: Custom config $BASE_CONFIG not found!"
        exit 1
    fi
fi

# 4. Tuning
if [ -f "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG" ]; then
    echo "🧪 Merging Tuning Profile: $TUNING_CONFIG"
    ./scripts/kconfig/merge_config.sh -m .config "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG"
fi

# 5. Sanitization
echo "🧹 Stripping Keys and Finalizing Config..."
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
make ARCH="$TARGET_ARCH" LLVM=1 olddefconfig

# --- 6. Versioning Strategy ---
OFFICIAL_VER=$(dpkg-parsechangelog -S Version)
TIMESTAMP=$(date +%Y%m%d)
SCHED_PRIORITY=$([ "$SCHEDULER_LABEL" == "bore" ] && echo "200" || echo "100")
PKG_VERSION="${OFFICIAL_VER}+harper.${SCHED_PRIORITY}.${SCHEDULER_LABEL}.${TIMESTAMP}"
echo "🏷️  Harper Identity: $PKG_VERSION"

# --- 7. Compile (The Linker Fix) ---
echo "🏗  Compiling Harper-Kernel ($TARGET_ARCH)..."

# 1. BUILD THE ARGUMENT ARRAY
# We use a bash array to safely handle spaces in arguments.
MAKE_ARGS=(
    ARCH="$TARGET_ARCH"
    CROSS_COMPILE=x86_64-linux-gnu-
    LLVM=1
    LLVM_IAS=1
    PKG_CONFIG="$PKG_CONFIG_TOOL"
    KCFLAGS="$USER_KCFLAGS"
    KDEB_SOURCENAME="$KDEB_NAME"
    KDEB_PKGVERSION="$PKG_VERSION"
    KDEB_CHANGELOG_DIST="trixie"
    -j"$FINAL_JOBS"
)

# 2. INJECT HOST OVERRIDES (The Critical "fuse-ld" Fix)
if [ "$HOST_ARCH" != "x86_64" ] && [ "$TARGET_ARCH" == "x86_64" ]; then
    echo "🔗 Injecting Cross-Build Overrides for Tools..."
    
    # We add '-fuse-ld=lld' to ensure Clang uses the multi-arch LLVM linker
    # instead of the single-arch system linker (/usr/bin/ld).
    MAKE_ARGS+=(
        "HOSTCC=clang --target=x86_64-linux-gnu -fuse-ld=lld"
        "HOSTLD=ld.lld"
        "HOSTCFLAGS=-I/usr/include/x86_64-linux-gnu"
        "HOSTLDFLAGS=-L/usr/lib/x86_64-linux-gnu -fuse-ld=lld"
        "CC=clang --target=x86_64-linux-gnu -fuse-ld=lld"
        "LD=ld.lld"
    )
fi

# 3. CLEAN & SYNC
if [ "$INCREMENTAL_BUILD" != "true" ]; then
    echo "🧹 Fresh Build: Cleaning artifacts..."
    make ARCH="$TARGET_ARCH" LLVM=1 clean
fi
make ARCH="$TARGET_ARCH" LLVM=1 olddefconfig

# 4. FIRE THE FORGE
# "${MAKE_ARGS[@]}" expands the array safely, passing the complex flags correctly.
make "${MAKE_ARGS[@]}" bindeb-pkg

# --- 8. Artifact Collection ---
mkdir -p "$CONTAINER_OUTPUT_DIR"
echo "📦 Exporting artifacts to: $CONTAINER_OUTPUT_DIR"

find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.deb" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.changes" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.buildinfo" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +

BZ_PATH=$(find . -name bzImage | head -n 1)
[ -f "$BZ_PATH" ] && cp "$BZ_PATH" "$CONTAINER_OUTPUT_DIR/bzImage"
[ -f .config ] && cp .config "$CONTAINER_OUTPUT_DIR/kernel.config"

echo "✅ Smelt Complete."