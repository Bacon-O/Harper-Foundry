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
PKG_CONFIG_TOOL="pkg-config"

# --- 2. PREPARE THE BUILD ENV (The Wrapper Fix) ---
# We create a wrapper script to handle the complex flags.
# This avoids all shell quoting and 'unrecognized option' errors in Make.
if [ "$HOST_ARCH" != "x86_64" ] && [ "$TARGET_ARCH" == "x86_64" ]; then
    echo "🔧 Cross-Compiling Detected ($HOST_ARCH -> $TARGET_ARCH)"
    PKG_CONFIG_TOOL="x86_64-linux-gnu-pkg-config"
    
    # 1. Find where Debian hides the x86 libgcc (solves 'unable to find -lgcc')
    GCC_LIB_PATH=$(find /usr/lib/gcc/x86_64-linux-gnu -name "libgcc.a" | head -n 1 | xargs dirname)
    echo "📍 Found GCC Libs at: $GCC_LIB_PATH"

    # 2. Create the Wrapper Script
    cat <<EOF > /usr/bin/x86-clang
#!/bin/sh
# Wrapper to force x86 target and LLD linker
exec clang --target=x86_64-linux-gnu -fuse-ld=lld -L${GCC_LIB_PATH} "\$@"
EOF
    chmod +x /usr/bin/x86-clang
    
    # 3. Set our compilers to use the wrapper
    MY_CC="x86-clang"
    MY_HOSTCC="x86-clang"
    MY_HOSTLD="ld.lld"
else
    echo "🔧 Native Build Detected ($HOST_ARCH)"
    MY_CC="clang"
    MY_HOSTCC="clang"
    MY_HOSTLD="ld.lld"
fi

# 3. Prepare Source
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

# 4. Base Configuration
# We use our wrapper (MY_CC) or standard clang depending on arch
if [[ "$BASE_CONFIG" == "defconfig" || "$BASE_CONFIG" == "tinyconfig" ]]; then
    echo "🐣 Applying standard base: $BASE_CONFIG"
    make ARCH="$TARGET_ARCH" CC="$MY_CC" LLVM=1 "$BASE_CONFIG"
else
    echo "📄 Applying custom base: $BASE_CONFIG"
    if [ -f "${CONTAINER_CONFIG_DIR}/$BASE_CONFIG" ]; then
        cp "${CONTAINER_CONFIG_DIR}/$BASE_CONFIG" .config
        make ARCH="$TARGET_ARCH" CC="$MY_CC" LLVM=1 olddefconfig
    else
        echo "❌ ERROR: Custom config $BASE_CONFIG not found!"
        exit 1
    fi
fi

# 5. Tuning
if [ -f "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG" ]; then
    echo "🧪 Merging Tuning Profile: $TUNING_CONFIG"
    ./scripts/kconfig/merge_config.sh -m .config "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG"
fi

# 6. Sanitization
echo "🧹 Stripping Keys and Finalizing Config..."
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
make ARCH="$TARGET_ARCH" CC="$MY_CC" LLVM=1 olddefconfig

# --- 7. Versioning Strategy ---
OFFICIAL_VER=$(dpkg-parsechangelog -S Version)
TIMESTAMP=$(date +%Y%m%d)
SCHED_PRIORITY=$([ "$SCHEDULER_LABEL" == "bore" ] && echo "200" || echo "100")
PKG_VERSION="${OFFICIAL_VER}+harper.${SCHED_PRIORITY}.${SCHEDULER_LABEL}.${TIMESTAMP}"
echo "🏷️  Harper Identity: $PKG_VERSION"

# --- 8. Compile (The Wrapper Execution) ---
echo "🏗  Compiling Harper-Kernel ($TARGET_ARCH)..."

# 1. CLEAN
if [ "$INCREMENTAL_BUILD" != "true" ]; then
    echo "🧹 Fresh Build: Cleaning artifacts..."
    make ARCH="$TARGET_ARCH" CC="$MY_CC" LLVM=1 clean
fi
make ARCH="$TARGET_ARCH" CC="$MY_CC" LLVM=1 olddefconfig

# 2. FIRE THE FORGE
# We use the MAKE_ARGS array to pass the environment-specific compilers.
# This is safe, clean, and prevents 'unrecognized option' errors.
MAKE_ARGS=(
    ARCH="$TARGET_ARCH"
    CROSS_COMPILE=x86_64-linux-gnu-
    LLVM=1
    PKG_CONFIG="$PKG_CONFIG_TOOL"
    CC="$MY_CC"
    HOSTCC="$MY_HOSTCC"
    HOSTLD="$MY_HOSTLD"
    KCFLAGS="$USER_KCFLAGS"
    KDEB_SOURCENAME="$KDEB_NAME"
    KDEB_PKGVERSION="$PKG_VERSION"
    KDEB_CHANGELOG_DIST="trixie"
    -j"$FINAL_JOBS"
)

# Add extra includes for host tools if cross-compiling
if [ "$HOST_ARCH" != "x86_64" ] && [ "$TARGET_ARCH" == "x86_64" ]; then
     MAKE_ARGS+=(
        "HOSTCFLAGS=-I/usr/include/x86_64-linux-gnu"
        "HOSTLDFLAGS=-L/usr/lib/x86_64-linux-gnu -L${GCC_LIB_PATH}"
     )
fi

make "${MAKE_ARGS[@]}" bindeb-pkg

# --- 9. Artifact Collection ---
mkdir -p "$CONTAINER_OUTPUT_DIR"
echo "📦 Exporting artifacts to: $CONTAINER_OUTPUT_DIR"

find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.deb" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.changes" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.buildinfo" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +

BZ_PATH=$(find . -name bzImage | head -n 1)
[ -f "$BZ_PATH" ] && cp "$BZ_PATH" "$CONTAINER_OUTPUT_DIR/bzImage"
[ -f .config ] && cp .config "$CONTAINER_OUTPUT_DIR/kernel.config"

echo "✅ Smelt Complete."