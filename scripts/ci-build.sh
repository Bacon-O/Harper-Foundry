#!/bin/bash
set -e

# ==============================================================================
#  HARPER-KERNEL FOUNDRY: MAIN SMELTING SCRIPT
#  "The heat of the forge reveals the strength of the steel."
# ==============================================================================

# 1. Load Fuel (Environment Variables)
#    Checks for the setup script, defaults to local vars if missing for testing.
if [ -f "/opt/factory/scripts/env_setup.sh" ]; then
    source /opt/factory/scripts/env_setup.sh
else
    echo "⚠️  Warning: env_setup.sh not found. Using local defaults."
    # Fallback defaults for testing without the full pipeline
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
#    Ensures files created by root (Docker) are owned by the host user (You)
cleanup_internal() {
    echo "⚖️  Internal Fix: Reclaiming ownership for Host UID: $HOST_UID"
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_BUILD_ROOT" 2>/dev/null || true
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_OUTPUT_DIR" 2>/dev/null || true
}
trap cleanup_internal EXIT

echo "🚀 Starting Harper-Kernel Foundry Smelt..."
echo "🧵 Parallelism: Using $FINAL_JOBS threads."

# --- Auto-Detect Architecture & Pkg-Config ---
#    Detects if we are cross-compiling (ARM -> x86) and adjusts tools accordingly.
HOST_ARCH=$(uname -m)

if [ "$HOST_ARCH" != "x86_64" ] && [ "$TARGET_ARCH" == "x86_64" ]; then
    echo "🔧 Cross-Compiling Detected ($HOST_ARCH -> $TARGET_ARCH)"
    echo "   Using x86_64 wrapper for pkg-config"
    # Important: Uses the wrapper to prevent pulling ARM64 flags for x86 builds
    PKG_CONFIG_TOOL="x86_64-linux-gnu-pkg-config"
else
    echo "🔧 Native Build Detected ($HOST_ARCH)"
    PKG_CONFIG_TOOL="pkg-config"
fi

# 2. Prepare Source
echo "🔧 Verifying packaging tools..."
# Ensure we have the tools to patch and link
apt-get update && apt-get install -y rsync llvm curl patch

mkdir -p "$CONTAINER_BUILD_ROOT"
cd "$CONTAINER_BUILD_ROOT"

echo "📥 Fetching Source: $KERNEL_SOURCE"
# Pulls the source code defined in your env (e.g., linux/trixie-backports)
apt-get source -y "$KERNEL_SOURCE"
cd linux-*/ || { echo "❌ ERROR: Source directory not found!"; exit 1; }

# --- 2.5. Inject Patches (BORE Scheduler) ---
echo "💉 Injecting Custom Scheduler..."
SCHEDULER_LABEL="eevdf" # Default fallback

if [ -n "$BORE_PATCH_URL" ]; then
    echo "   Fetching patch from: $BORE_PATCH_URL"
    if curl -fLo bore.patch "$BORE_PATCH_URL"; then
        # Try applying patch with fuzzy matching (-F 3)
        if patch -p1 -F 3 < bore.patch; then
            echo "   ✅ Patch applied successfully."
            SCHEDULER_LABEL="bore"
        else
            echo "   ⚠️  Patch failed! Falling back to standard EEVDF scheduler."
        fi
    else
        echo "   ❌ ERROR: Download failed. Skipping patch."
    fi
else
    echo "⏩ No patch URL defined. Skipping injection."
fi

# 3. Base Configuration
if [[ "$BASE_CONFIG" == "defconfig" || "$BASE_CONFIG" == "tinyconfig" ]]; then
    echo "🐣 Applying standard base: $BASE_CONFIG"
    make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" "$BASE_CONFIG"
else
    echo "📄 Applying custom base: $BASE_CONFIG"
    if [ -f "${CONTAINER_CONFIG_DIR}/$BASE_CONFIG" ]; then
        cp "${CONTAINER_CONFIG_DIR}/$BASE_CONFIG" .config
        make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" olddefconfig
    else
        echo "❌ ERROR: Custom config $BASE_CONFIG not found!"
        exit 1
    fi
fi

# 4. Tuning
echo "🧪 Merging Tuning Profile: $TUNING_CONFIG"
if [ -f "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG" ]; then
    ./scripts/kconfig/merge_config.sh -m .config "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG"
else
    echo "⚠️  Warning: Tuning file not found. Skipping merge."
fi

# 5. Sanitization
echo "🧹 Stripping Keys and Finalizing Config..."
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" olddefconfig

# --- 6. Versioning Strategy (The Harper Offset) ---
#    Calculates priority: 200 for BORE (Custom), 100 for EEVDF (Standard)
if [ "$SCHEDULER_LABEL" == "bore" ]; then
    SCHED_PRIORITY="200"
else
    SCHED_PRIORITY="100"
fi

OFFICIAL_VER=$(dpkg-parsechangelog -S Version)
TIMESTAMP=$(date +%Y%m%d)
# Syntax: <DebianVer> +harper. <Priority> . <Label> . <Date>
PKG_VERSION="${OFFICIAL_VER}+harper.${SCHED_PRIORITY}.${SCHEDULER_LABEL}.${TIMESTAMP}"

echo "🏷️  Harper Identity: $PKG_VERSION"

# --- 7. Compile (The Critical Fix) ---
echo "🏗  Compiling Harper-Kernel ($TARGET_ARCH)..."

# 1. NUKE ALL FLAGS (The "Scorched Earth" Policy)
#    We unset standard flags too, just in case dpkg set them.
unset HOSTCFLAGS HOSTLDFLAGS
unset CFLAGS LDFLAGS CPPFLAGS
unset KBUILD_HOSTCFLAGS KBUILD_HOSTLDFLAGS

# 2. FORCE CLEAN (Kill the Zombies)
if [ "$INCREMENTAL_BUILD" == "true" ]; then
    echo "♻️  Incremental Mode: Skipping 'make clean' to preserve object files."
else
    echo "🧹 Fresh Build: Cleaning previous artifacts..."
    make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" clean
fi

# 3. RESTORE CONFIG
#    'make clean' might delete the .config, so we ensure it's set.
#    (Re-running olddefconfig is fast and safe)
make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" olddefconfig

# 4. FIRE THE FORGE (With explicit overrides)
make ARCH="$TARGET_ARCH" \
     $CC_TOOLCHAIN \
     "$CROSS_CMD" \
     PKG_CONFIG="$PKG_CONFIG_TOOL" \
     KCFLAGS="$USER_KCFLAGS" \
     KDEB_SOURCENAME="$KDEB_NAME" \
     KDEB_PKGVERSION="$PKG_VERSION" \
     HOSTCFLAGS="" HOSTLDFLAGS="" \
     -j"$FINAL_JOBS" bindeb-pkg

# --- 8. Artifact Collection ---
mkdir -p "$CONTAINER_OUTPUT_DIR"
echo "📦 Exporting artifacts to: $CONTAINER_OUTPUT_DIR"

# 1. Grab the Debian Packages (look in the build root)
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.deb" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.changes" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.buildinfo" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +

# 2. Grab the bzImage (The "relative" find that worked before)
BZ_PATH=$(find . -name bzImage | head -n 1)
if [ -f "$BZ_PATH" ]; then
    cp "$BZ_PATH" "$CONTAINER_OUTPUT_DIR/bzImage"
    echo "   ✅ Captured bzImage"
fi

# 3. Grab the Config
[ -f .config ] && cp .config "$CONTAINER_OUTPUT_DIR/kernel.config"

echo "✅ Smelt Complete."