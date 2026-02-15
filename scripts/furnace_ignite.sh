#!/bin/bash
set -e

# 1. MUST Load Environment First to define variables
if [ -z "$REPO_ROOT" ]; then
    source "$(dirname "$0")/env_setup.sh" "$@"
fi

# 3. Image Preparation
echo "🔥 Igniting the Furnace..."
if [ "$FOUNDRY_IMAGE_TYPE" == "build" ]; then
    BUILD_ARGS="--build-arg USER_UID=$HOST_UID --build-arg USER_GID=$HOST_GID"
    [ "$DOCKER_REBUILD" == "true" ] && BUILD_ARGS="$BUILD_ARGS --no-cache"
    echo "🏗️  Building $IMAGE_NAME from $DOCKERFILE_PATH..."
    echo "   Using UID:GID = $HOST_UID:$HOST_GID"
    docker build $BUILD_ARGS -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" .
else
    echo "🌐 Pulling $REMOTE_IMAGE_REF..."
    docker pull "$REMOTE_IMAGE_REF"
    docker tag "$REMOTE_IMAGE_REF" "$IMAGE_NAME"
fi

# 4. Dynamic Execution
echo "🚀 Launching Containerized Process: $FOUNDRY_EXEC"
echo "Kernel version will be appended with: $LOCALVERSION"
docker run -i --rm \
    -e CONTAINER_OUTPUT_DIR="$CONTAINER_OUTPUT_DIR" \
    -e GITHUB_RUN_ID="$GITHUB_RUN_ID" \
    -e INCREMENTAL_BUILD="$INCREMENTAL_BUILD" \
    -e ARCH="$TARGET_ARCH" \
    -e CROSS_COMPILE="$CROSS_COMPILE" \
    -e KBUILD_BUILD_ARCH="$TARGET_ARCH" \
    -e DEB_TARGET_ARCH="$DEB_TARGET_ARCH" \
    -v "${HOST_QEMU_STATIC=}":/usr/bin/qemu-x86_64-static:ro \
    -v "${PROJECT_ROOT}:/build" \
    -v "${REPO_ROOT}/scripts:${CONTAINER_SCRIPTS_DIR}:ro" \
    -v "${REPO_ROOT}/configs:${CONTAINER_CONFIG_DIR}:ro" \
    -v "${REPO_ROOT}/params:/opt/factory/params:ro" \
    -v "${CURRENT_DIST_DIR}:/opt/factory/output" \
    -w "/build" \
    "$IMAGE_NAME" \
    bash "${CONTAINER_SCRIPTS_DIR}/${FOUNDRY_EXEC}" "$@"