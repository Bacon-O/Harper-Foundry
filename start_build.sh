#!/bin/bash
set -e

IMAGE_NAME="debian-harper-worker"

# Resolve Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE_PATH="${SCRIPT_DIR}/docker/docker_arm64_x86_cross_full_auto.dockerfile"

# This is where the .debs will appear on your OCI host
HOST_BUILD_DATA_PATH="/mnt/build-data/Debian-Harper/worker"
CONTAINER_BUILD_PATH="/build"

echo "--- Building Docker image: ${IMAGE_NAME} ---"
docker build -t "${IMAGE_NAME}" -f "${DOCKERFILE_PATH}" "${SCRIPT_DIR}"

mkdir -p "${HOST_BUILD_DATA_PATH}"

# ... (rest of your setup above stays the same)

echo "--- Starting Build in Background ---"

# 1. Remove the '#' so the script actually executes
# 2. Use 'bash /opt/factory/scripts/ci-build_slim.sh' as the command
CONTAINER_ID=$(docker run -d \
    --rm \
    -v "${HOST_BUILD_DATA_PATH}:${CONTAINER_BUILD_PATH}" \
    -v "$(pwd)/scripts:/opt/factory/scripts:ro" \
    -v "$(pwd)/configs:/opt/factory/configs:ro" \
    -w "${CONTAINER_BUILD_PATH}" \
    "${IMAGE_NAME}" \
    bash /opt/factory/scripts/ci-build_slim.sh)

echo "🚀 Build started! Container ID: ${CONTAINER_ID}"
echo "📝 Run: docker logs -f ${CONTAINER_ID}"