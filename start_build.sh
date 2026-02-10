#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define image name
IMAGE_NAME="debian-harper-worker"

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE_PATH="${SCRIPT_DIR}/docker/docker_arm64_x86_cross.dockerfile"

# Check if Dockerfile exists
if [ ! -f "${DOCKERFILE_PATH}" ]; then
    echo "Error: Dockerfile not found at ${DOCKERFILE_PATH}"
    echo "Please create a Dockerfile in the same directory as this script."
    exit 1
fi

echo "--- Building Docker image: ${IMAGE_NAME} ---"
# Build the Docker image. The context for the build is the script's directory.
docker build -t "${IMAGE_NAME}" -f "${DOCKERFILE_PATH} ."

echo "--- Docker image built successfully. ---"

# Define the host path to mount
HOST_BUILD_DATA_PATH="/mnt/build-data/Debian-Harper/worker"
# Define the container path to mount to
CONTAINER_BUILD_PATH="/build"

# Check if the host mount path exists
if [ ! -d "${HOST_BUILD_DATA_PATH}" ]; then
    echo "Warning: Host mount path '${HOST_BUILD_DATA_PATH}' does not exist."
    echo "The Docker container might not find the expected data."
    # Optionally, you could exit here if the path is critical.
fi

# Ensure the host build data directory exists
echo "Ensuring host build directory '${HOST_BUILD_DATA_PATH}' exists..."
mkdir -p "${HOST_BUILD_DATA_PATH}"

echo "--- Starting Docker container '${IMAGE_NAME}' ---"
echo "Mounting host path '${HOST_BUILD_DATA_PATH}' to container path '${CONTAINER_BUILD_PATH}'"

# Start the Docker container with the mounted volume and bash shell
# -it: Interactive and pseudo-TTY allocation (for a shell)
# --rm: Automatically remove the container when it exits
# -v: Mount a volume
docker run -it --rm -v "${HOST_BUILD_DATA_PATH}:${CONTAINER_BUILD_PATH}" "${IMAGE_NAME}" bash

echo "--- Docker container exited. ---"
