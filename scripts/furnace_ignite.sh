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
    echo "🏗️  Building $CONTAINER_IMAGE_NAME from $DOCKERFILE_PATH..."
    echo "   Using UID:GID = $HOST_UID:$HOST_GID"
    docker build $BUILD_ARGS -t "$CONTAINER_IMAGE_NAME" -f "$DOCKERFILE_PATH" .
else
    echo "🌐 Pulling $REMOTE_IMAGE_REF..."
    docker pull "$REMOTE_IMAGE_REF"
    docker tag "$REMOTE_IMAGE_REF" "$CONTAINER_IMAGE_NAME"
fi

# 4. Dynamic Execution
echo "🚀 Launching Containerized Process: $FOUNDRY_EXEC"
echo "Kernel version will be appended with: $LOCALVERSION"

# Determine entrypoint based on mode
if [ "$SHELL_MODE" == "true" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🐚 HarperShell Mode Activated"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Configuration: $(basename $PARAMS_FILE)"
    echo ""
    echo "📂 Mounted Directories:"
    echo "   /build                     (source root)"
    echo "   /opt/factory/plugins       (build plugins)"
    echo "   /opt/factory/configs       (kernel configs)"
    echo "   /opt/factory/scripts       (build scripts)"
    echo "   /opt/factory/output        (build artifacts)"
    echo ""
    echo "🔧 Environment:"
    echo "   Target Arch:   $TARGET_ARCH"
    echo "   Host Arch:     $HOST_ARCH"
    echo "   Jobs:          $FINAL_JOBS"
    echo "   Docker Image:  $DOCKERFILE_PATH"
    echo ""
    echo "⚠️  Note: Build scripts have not been run yet."
    echo "   Source files may not be fetched. You may need to:"
    echo "   • apt-get source <kernel-source>"
    echo "   • Or manually fetch files from /build"
    echo ""
    echo "💡 Tips:"
    echo "   • cd /build to access source code"
    echo "   • cd /opt/factory/output to see build results"
    echo "   • Type 'exit' to leave the container"
    echo ""
    echo "🔑 Escalation (if container supports it):"
    echo "   • sudo su - (to become root for package installation)"
    echo "   • sudo apt-get install <package> (install packages as needed)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    DOCKER_FLAGS="-it"
    CONTAINER_CMD="bash"
else
    DOCKER_FLAGS="-i"
    # Standardized container paths - these are constants defined by the Docker image
    CONTAINER_CMD="bash \"/opt/factory/scripts/${FOUNDRY_EXEC}\" \"\$@\""
fi

eval "docker run $DOCKER_FLAGS --rm \
    -e CONTAINER_OUTPUT_DIR=\"/opt/factory/output\" \
    -e GITHUB_RUN_ID=\"$GITHUB_RUN_ID\" \
    -e INCREMENTAL_BUILD=\"$INCREMENTAL_BUILD\" \
    -e ARCH=\"$TARGET_ARCH\" \
    -e CROSS_COMPILE=\"$CROSS_COMPILE\" \
    -e KBUILD_BUILD_ARCH=\"$TARGET_ARCH\" \
    -e DEB_HOST_ARCH=\"$DEB_HOST_ARCH\" \
    -e PRODUCTION_CONFIG=\"$PRODUCTION_CONFIG\" \
    -e OVERRIDE_PARAMS=\"$OVERRIDE_PARAMS\" \
    -v \"${HOST_QEMU_STATIC=}\":/usr/bin/qemu-x86_64-static:ro \
    -v "${BUILD_WORKSPACE_DIR}:/build" \
    -v \"${REPO_ROOT}/scripts:/opt/factory/scripts:ro\" \
    -v \"${REPO_ROOT}/configs:/opt/factory/configs:ro\" \
    -v \"${REPO_ROOT}/params:/opt/factory/params:ro\" \
    -v "${BUILD_OUTPUT_DIR}:/opt/factory/output" \
    -w \"/build\" \
    \"$CONTAINER_IMAGE_NAME\" \
    $CONTAINER_CMD"