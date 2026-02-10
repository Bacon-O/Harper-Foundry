#!/bin/bash
set -e

# 1. Load Environment
source "$(dirname "$0")/env_setup.sh" "$@"

echo "🧼 SCRUBBING THE CRUCIBLE: Deep Decontamination Initiated..."

# 2. Wipe all Build Artifacts
if [ -d "$HOST_DIST_BASE" ]; then
    echo "🗑️  Removing all artifacts from $HOST_DIST_BASE..."
    rm -rf "${HOST_DIST_BASE:?}"/build_* fi

# 3. Docker Housekeeping
echo "🐳 Pruning Docker Builder Cache for $IMAGE_NAME..."
# Removes stopped containers and dangling images to reclaim host space
docker container prune -f
docker image prune -f

echo "✨ Crucible scrubbed. The next smelt will be 100% fresh."