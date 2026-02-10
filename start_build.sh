#!/bin/bash
# Exit on error
set -e

IMAGE_NAME="debian-harper-worker"

# Resolve Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE_PATH="${SCRIPT_DIR}/docker/docker_arm64_x86_cross_full_auto.dockerfile"
HOST_BUILD_DATA_PATH="/mnt/build-data/Debian-Harper/worker"
CONTAINER_BUILD_PATH="/build"

# 1. Build the "Foundry" Image
echo "--- Building Docker image: ${IMAGE_NAME} ---"
docker build -t "${IMAGE_NAME}" -f "${DOCKERFILE_PATH}" "${SCRIPT_DIR}"

# 2. Setup Persistence
mkdir -p "${HOST_BUILD_DATA_PATH}"

echo "--- Starting Build in Background ---"

# 3. Launch the Cross-Compile Factory
# We mount scripts and configs as Read-Only (:ro) for safety
CONTAINER_ID=$(docker run -d \
    --rm \
    -v "${HOST_BUILD_DATA_PATH}:${CONTAINER_BUILD_PATH}" \
    -v "${SCRIPT_DIR}/scripts:/opt/factory/scripts:ro" \
    -v "${SCRIPT_DIR}/configs:/opt/factory/configs:ro" \
    -w "${CONTAINER_BUILD_PATH}" \
    "${IMAGE_NAME}" \
    bash "/opt/factory/scripts/ci-build_slim.sh")

echo "🚀 Build started! Container ID: ${CONTAINER_ID}"
echo "📝 To watch the 5800X3D cross-compile, run: docker logs -f ${CONTAINER_ID}"