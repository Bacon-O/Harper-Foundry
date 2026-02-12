#!/bin/bash
set -e

# 1. MUST Load Environment First to define variables
if [ -z "$IMAGE_NAME" ]; then
    source "$(dirname "$0")/env_setup.sh" "$@"
fi

# 2. Set the Trap now that $HOST_UID and $CURRENT_DIST_DIR are known
cleanup_permissions() {
    echo "⚖️ Reclaiming artifact ownership for host user ($HOST_UID)..."
    if [ -d "$CURRENT_DIST_DIR" ]; then
        # This is our safety net if the internal container trap fails
        sudo chown -R "$HOST_UID:$HOST_GID" "$CURRENT_DIST_DIR" 2>/dev/null || true
    fi
}
trap cleanup_permissions EXIT

# 3. Image Preparation
echo "🔥 Igniting the Furnace..."
if [ "$FOUNDRY_IMAGE_TYPE" == "build" ]; then
    BUILD_ARGS=""
    [ "$DOCKER_REBUILD" == "true" ] && BUILD_ARGS="--no-cache"
    echo "🏗️  Building $IMAGE_NAME from $DOCKERFILE_PATH..."
    docker build $BUILD_ARGS -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" .
else
    echo "🌐 Pulling $REMOTE_IMAGE_REF..."
    docker pull "$REMOTE_IMAGE_REF"
    docker tag "$REMOTE_IMAGE_REF" "$IMAGE_NAME"
fi

# 4. Dynamic Execution
echo "🚀 Launching Containerized Process: $FOUNDRY_EXEC"
echo "Kernel version will be appended with: $LOCALVERSION"
# Note: We pass CONTAINER_OUTPUT_DIR explicitly so ci-build.sh sees it
docker run -i --rm \
    -e HOST_UID="$HOST_UID" \
    -e HOST_GID="$HOST_GID" \
    -e LOCALVERSION="$LOCALVERSION" \
    -e CONTAINER_OUTPUT_DIR="/opt/factory/output" \
    -e GITHUB_RUN_ID="$GITHUB_RUN_ID" \
    -e INCREMENTAL_BUILD="$INCREMENTAL_BUILD" \
    # --- ADDED ARCHITECTURE LOGIC ---
    -e ARCH="x86_64" \
    -e CROSS_COMPILE="x86_64-linux-gnu-" \
    -e KBUILD_BUILD_ARCH="x86_64" \
    -e DEB_TARGET_ARCH="amd64" \
    -v /usr/bin/qemu-x86_64-static:/usr/bin/qemu-x86_64-static:ro \
    # --------------------------------
    -v "${BLOCK_VOL_PATH}:/build" \
    -v "${REPO_ROOT}/scripts:${CONTAINER_SCRIPTS_DIR}:ro" \
    -v "${REPO_ROOT}/configs:${CONTAINER_CONFIG_DIR}:ro" \
    -v "${REPO_ROOT}/params:/opt/factory/params:ro" \
    -v "${CURRENT_DIST_DIR}:/opt/factory/output" \
    -w "/build" \
    "$IMAGE_NAME" \
    bash "${CONTAINER_SCRIPTS_DIR}/${FOUNDRY_EXEC}" "$@"