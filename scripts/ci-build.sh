#!/bin/bash
set -e

# ==============================================================================
#  HARPER-KERNEL FOUNDRY: MAIN SMELTING SCRIPT
# ==============================================================================

# 1. Load Fuel (Environment Variables)
# if [ -f "/opt/factory/scripts/env_setup.sh" ]; then
#     source /opt/factory/scripts/env_setup.sh
# else
#     echo "⚠️  Warning: env_setup.sh not found. Using local defaults."
#     HOST_UID=${HOST_UID:-1000}
#     HOST_GID=${HOST_GID:-1000}
#     CONTAINER_BUILD_ROOT="/build"
#     CONTAINER_OUTPUT_DIR="/opt/factory/output"
#     CONTAINER_CONFIG_DIR="/opt/factory/configs"
#     KERNEL_SOURCE="linux-source"
#     TARGET_ARCH="x86_64"
#     FINAL_JOBS=$(nproc)
# fi

# --- Cleanup Trap ---
# cleanup_internal() {
#     echo "⚖️  Internal Fix: Reclaiming ownership for Host UID: $HOST_UID"
#     chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_BUILD_ROOT" 2>/dev/null || true
#     chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_OUTPUT_DIR" 2>/dev/null || true
# }
# trap cleanup_internal EXIT

# echo "🚀 Starting Harper-Kernel Foundry Smelt..."
# echo "🧵 Parallelism: Using $FINAL_JOBS threads."

# HOST_ARCH=$(uname -m)

# 2. Prepare Source
echo "🔧 Verifying packaging tools..."
# Ensure we have the x86 gcc libs for linking
# apt-get update && apt-get install -y rsync llvm curl patch libgcc-12-dev:amd64

# mkdir -p "$CONTAINER_BUILD_ROOT"
# cd "$CONTAINER_BUILD_ROOT"

# echo "📥 Fetching Source: $KERNEL_SOURCE"
# apt-get source -y "$KERNEL_SOURCE"
cd linux-*/ || { echo "❌ ERROR: Source directory not found!"; exit 1; }

# --- 2.5. Inject Patches ---
# echo "💉 Injecting Custom Scheduler..."
# SCHEDULER_LABEL="eevdf"
# if [ -n "$BORE_PATCH_URL" ]; then
#     if curl -fLo bore.patch "$BORE_PATCH_URL"; then
#         if patch -p1 -F 3 < bore.patch; then
#             echo "   ✅ Patch applied successfully."
#             SCHEDULER_LABEL="bore"
#         else
#             echo "   ⚠️  Patch failed! Falling back to standard EEVDF."
#         fi
#     fi
# fi

# 5. Tuning
# if [ -f "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG" ]; then
#     echo "🧪 Merging Tuning Profile: $TUNING_CONFIG"
#     ./scripts/kconfig/merge_config.sh -m .config "${CONTAINER_CONFIG_DIR}/$TUNING_CONFIG"
# fi

# 6. Sanitization
# echo "🧹 Stripping Keys and Finalizing Config..."
# ./scripts/config --disable SYSTEM_TRUSTED_KEYS
# ./scripts/config --disable SYSTEM_REVOCATION_KEYS
# ./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
# make "${MAKE_ARGS[@]}" olddefconfig

# --- 7. Versioning Strategy ---
# OFFICIAL_VER=$(dpkg-parsechangelog -S Version)
# TIMESTAMP=$(date +%Y%m%d)
# SCHED_PRIORITY=$([ "$SCHEDULER_LABEL" == "bore" ] && echo "200" || echo "100")
# PKG_VERSION="${OFFICIAL_VER}+harper.${SCHED_PRIORITY}.${SCHEDULER_LABEL}.${TIMESTAMP}"
# echo "🏷️  Harper Identity: $PKG_VERSION"

# --- 8. Compile ---
# echo "🏗  Compiling Harper-Kernel ($TARGET_ARCH)..."

# 1. CLEAN
# if [ "$INCREMENTAL_BUILD" != "true" ]; then
#     echo "🧹 Fresh Build: Cleaning artifacts..."
#     make "${MAKE_ARGS[@]}" clean
# fi

# export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig
# make ARCH=x86_64 allnoconfig
# ./scripts/config --file .config --enable 64BIT
# make ARCH=x86_64 allnoconfig

# 2. FIRE THE FORGE
# We use the array expansion "${MAKE_ARGS[@]}" to safely pass all flags
make -j$(nproc) \
    ARCH=x86_64 \
    CROSS_COMPILE=x86_64-linux-gnu- \
    KBUILD_BUILD_ARCH=x86_64 \
    DEB_BUILD_ARCH=arm64 \
    DEB_TARGET_ARCH=amd64 \
    CC="clang --target=x86_64-linux-gnu" \
    HOSTCC="clang --target=x86_64-linux-gnu" \
    HOSTLD="x86_64-linux-gnu-ld" \
    HOSTCFLAGS="-I/usr/include/x86_64-linux-gnu" \
    HOSTLDFLAGS="-L/usr/lib/x86_64-linux-gnu" \
    bindeb-pkg

# --- 9. Artifact Collection ---
# mkdir -p "$CONTAINER_OUTPUT_DIR"
# echo "📦 Exporting artifacts to: $CONTAINER_OUTPUT_DIR"

# find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.deb" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
# find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.changes" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +
# find "$CONTAINER_BUILD_ROOT" -maxdepth 2 -name "*.buildinfo" -exec mv -t "$CONTAINER_OUTPUT_DIR/" {} +

# BZ_PATH=$(find . -name bzImage | head -n 1)
# [ -f "$BZ_PATH" ] && cp "$BZ_PATH" "$CONTAINER_OUTPUT_DIR/bzImage"
# [ -f .config ] && cp .config "$CONTAINER_OUTPUT_DIR/kernel.config"

echo "✅ Smelt Complete."