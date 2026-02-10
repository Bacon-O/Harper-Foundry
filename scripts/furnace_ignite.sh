#!/bin/bash
set -e

# 1. Ensure Environment is loaded
if [ -z "$IMAGE_NAME" ]; then
    source "$(dirname "$0")/env_setup.sh" "$@"
fi

echo "🔥 Igniting the Furnace..."

# 2. Image Preparation
if [ "$FOUNDRY_IMAGE_TYPE" == "build" ]; then
    BUILD_ARGS=""
    [ "$DOCKER_REBUILD" == "true" ] && BUILD_ARGS="--no-cache"
    docker build $BUILD_ARGS -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" .
else
    docker pull "$REMOTE_IMAGE_REF"
    docker tag "$REMOTE_IMAGE_REF" "$IMAGE_NAME"
fi

echo "🚀 Launching Containerized Process: $FOUNDRY_EXEC"

# 3. Dynamic Execution
# We now call FOUNDRY_EXEC instead of a hardcoded ci-build.sh
docker run -i --rm \
    -e HOST_UID="$HOST_UID" \
    -e HOST_GID="$HOST_GID" \
    -v "${BLOCK_VOL_PATH}:/build" \
    -v "${REPO_ROOT}/scripts:${CONTAINER_SCRIPTS_DIR}:ro" \
    -v "${REPO_ROOT}/configs:${CONTAINER_CONFIG_DIR}:ro" \
    -v "${CURRENT_DIST_DIR}:${CONTAINER_OUTPUT_DIR}" \
    -w "/build" \
    "$IMAGE_NAME" \
    bash "${CONTAINER_SCRIPTS_DIR}/${FOUNDRY_EXEC}"