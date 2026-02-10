#!/bin/bash
set -e

# 1. Load Fuel
source /opt/factory/scripts/env_setup.sh

# --- Cleanup Trap ---
cleanup_internal() {
    echo "⚖️ Internal Fix: Reclaiming ownership for Host UID: $HOST_UID"
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_BUILD_ROOT" 2>/dev/null || true
    chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_OUTPUT_DIR" 2>/dev/null || true
}
trap cleanup_internal EXIT

# --- Auto-Detect Architecture & Pkg-Config ---
HOST_ARCH=$(uname -m)  # <--- WAS MISSING

if [ "$HOST_ARCH" != "x86_64" ] && [ "$TARGET_ARCH" == "x86_64" ]; then
    echo "🔧 Cross-Compiling Detected: Using x86_64 wrapper for pkg-config"
    PKG_CONFIG_TOOL="x86_64-linux-gnu-pkg-config"
else
    echo "🔧 Native Build Detected: Using standard pkg-config"
    PKG_CONFIG_TOOL="pkg-config"
fi

echo "🚀 Starting Harper-Kernel Foundry Smelt..."
echo "🧵 Parallelism: Using $FINAL_JOBS threads."

echo "🔧 Verifying packaging tools..."
apt-get update && apt-get install -y rsync llvm

# 2. Prepare Source
cd "$CONTAINER_BUILD_ROOT"
echo "📥 Fetching Source: $KERNEL_SOURCE"
apt-get source -y "$KERNEL_SOURCE"
cd linux-*/ || { echo "❌ ERROR: Source directory not found!"; exit 1; }

# --- 2.5. Inject Patches (BORE Scheduler) ---
echo "💉 Injecting BORE Scheduler..."
# Default label if patching fails or is skipped
SCHEDULER_LABEL="eevdf"

if [ -n "$BORE_PATCH_URL" ]; then
    echo "   Fetching patch from: $BORE_PATCH_URL"
    if curl -fLo bore.patch "$BORE_PATCH_URL"; then
        if patch -p1 -F 3 < bore.patch; then
            echo "   ✅ Patch applied successfully."
            SCHEDULER_LABEL="bore"  # <--- Label Updated on Success
        else
            echo "   ❌ ERROR: Patch application failed! (Falling back to EEVDF)"
            # Note: We don't exit 1 here, we let it fall back as per your strategy
        fi
    else
        echo "   ❌ ERROR: Download failed."
        exit 1
    fi
else
    echo "⏩ No patch URL defined. Skipping injection."
fi

# 3. Base Configuration
if [[ "$BASE_CONFIG" == "defconfig" || "$BASE_CONFIG" == "tinyconfig" ]]; then
    echo "🐣 Applying base: $BASE_CONFIG"
    make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" "$BASE_CONFIG"
else
    echo "📄 Applying custom base: $BASE_CONFIG"
    cp "${CONTAINER_CONFIG_DIR}/$BASE_CONFIG" .config
    make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" olddefconfig
fi

# 4. Tuning
echo "🧪 Merging Tuning: $TUNING_CONFIG"
./scripts/kconfig/merge_config.sh -m .config "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG"

# 5. Sanitization
echo "🧹 Stripping Keys and Finalizing Config..."
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
make ARCH="$TARGET_ARCH" "$CC_TOOLCHAIN" olddefconfig

# --- 6. Versioning Strategy (The Harper Offset) ---
# 200 = BORE (Preferred) | 100 = EEVDF (Fallback)
if [ "$SCHEDULER_LABEL" == "bore" ]; then
    SCHED_PRIORITY="200"
else
    SCHED_PRIORITY="100"
fi

OFFICIAL_VER=$(dpkg-parsechangelog -S Version)
TIMESTAMP=$(date +%Y%m%d)
# Syntax: <DebianVer> +harper. <Priority> . <Label>
PKG_VERSION="${OFFICIAL_VER}+harper.${SCHED_PRIORITY}.${SCHEDULER_LABEL}.${TIMESTAMP}"

echo "🏷️  Harper Identity: $PKG_VERSION"
echo "    (Base: $OFFICIAL_VER | Priority: $SCHED_PRIORITY)"

# --- 7. Compile ---
echo "🏗 Compiling Harper-Kernel ($TARGET_ARCH)..."
make ARCH="$TARGET_ARCH" \
     $CC_TOOLCHAIN \
     "$CROSS_CMD" \
     PKG_CONFIG="$PKG_CONFIG_TOOL" \
     KCFLAGS="$USER_KCFLAGS" \
     KDEB_SOURCENAME="$KDEB_NAME" \
     KDEB_PKGVERSION="$PKG_VERSION" \
     -j"$FINAL_JOBS" bindeb-pkg

# --- 8. Artifacts ---
mkdir -p "$CONTAINER_OUTPUT_DIR"
echo "📦 Exporting artifacts to: $CONTAINER_OUTPUT_DIR"

mv -f "$CONTAINER_BUILD_ROOT"/*.deb \
      "$CONTAINER_BUILD_ROOT"/*.changes \
      "$CONTAINER_BUILD_ROOT"/*.buildinfo \
      "$CONTAINER_OUTPUT_DIR/" 2>/dev/null || true

BZ_PATH=$(find arch/x86/boot/ -name bzImage | head -n 1)
if [ -f "$BZ_PATH" ]; then
    cp "$BZ_PATH" "$CONTAINER_OUTPUT_DIR/bzImage"
fi

cp .config "$CONTAINER_OUTPUT_DIR/kernel.config"
echo "✅ Smelt Complete."