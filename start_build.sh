#!/bin/bash
set -e

# === CONFIGURATION ===
IMAGE_NAME="debian-harper-worker"
# Paths on the OCI Host
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${REPO_ROOT}/docker/docker_arm64_x86_cross_full_auto.dockerfile"
BLOCK_VOL_PATH="/mnt/build-data/github_work/Debian-Harper"
BUILD_ID=$(date +%Y%m%d_%H%M)
DIST_OUT="${REPO_ROOT}/dist/build_${BUILD_ID}"

# Identity Injection (Dynamic)
USER_UID=$(id -u)
USER_GID=$(id -g)
# =====================

# Ensure directories exist
mkdir -p "${BLOCK_VOL_PATH}"
mkdir -p "${DIST_OUT}"

echo "--- 🛠 Building Docker Image: ${IMAGE_NAME} ---"
docker build -t "${IMAGE_NAME}" -f "${DOCKERFILE}" "${REPO_ROOT}"

echo "--- 🚀 Starting Build for User ${USER_UID}:${USER_GID} ---"

# Launch Foundry
docker run -i \
    --rm \
    -e HOST_UID="$USER_UID" \
    -e HOST_GID="$USER_GID" \
    -v "${BLOCK_VOL_PATH}:/build" \
    -v "${REPO_ROOT}/scripts:/opt/factory/scripts:ro" \
    -v "${REPO_ROOT}/configs:/opt/factory/configs:ro" \
    -v "${DIST_OUT}:/opt/factory/dist" \
    -w "/build" \
    "${IMAGE_NAME}" \
    bash /opt/factory/scripts/ci-build_slim.sh

echo "✅ Foundry process complete. Artifacts in: ${DIST_OUT}"