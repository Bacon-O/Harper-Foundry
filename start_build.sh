#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define image name
IMAGE_NAME="debian-harper-worker"

# Get the directory where the script is located, and define the relative and full paths to the Dockerfile
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE_PATH="${SCRIPT_DIR}/docker/docker_arm64_x86_cross_full_auto.dockerfile"

# Check if Dockerfile exists
if [ ! -f "${DOCKERFILE_PATH}" ]; then
    echo "Error: Dockerfile not found at ${DOCKERFILE_PATH}"
    echo "Please ensure the Dockerfile exists at the specified path."
    exit 1
fi

echo "--- Building Docker image: ${IMAGE_NAME} ---"
docker build -t "${IMAGE_NAME}" -f "${DOCKERFILE_PATH}" "${SCRIPT_DIR}"

echo "--- Docker image built successfully. ---"

# Define the host path to mount
HOST_BUILD_DATA_PATH="/mnt/build-data/Debian-Harper/worker"
# Define the container path to mount to
CONTAINER_BUILD_PATH="/build"

# Ensure the host build data directory exists
echo "Ensuring host build directory '${HOST_BUILD_DATA_PATH}' exists..."
mkdir -p "${HOST_BUILD_DATA_PATH}"

echo "--- Starting Build in Background ---"

# Start the Docker container in detached mode (-d)
CONTAINER_ID=$(docker run -d \
    -v "${HOST_BUILD_DATA_PATH}:${CONTAINER_BUILD_PATH}" \
    -v "${SCRIPT_DIR}/scripts:${CONTAINER_BUILD_PATH}/scripts" \
    -v "${SCRIPT_DIR}/configs:${CONTAINER_BUILD_PATH}/configs" \
    -w "${CONTAINER_BUILD_PATH}" \
    "${IMAGE_NAME}" \
    bash "${CONTAINER_BUILD_PATH}/scripts/ci-build_slim.sh")

echo "Build started! Container ID: ${CONTAINER_ID}"
echo "To view logs, run: docker logs -f ${CONTAINER_ID}"
