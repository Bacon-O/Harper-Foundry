#!/bin/bash
set -e

DEEP_CLEAN="false"
ARGS=()
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --deep|--scrub)
            DEEP_CLEAN="true"
            shift
            ;;
        *)
            # Pass unknown args to env_setup
            ARGS+=("$1")
            shift
            ;;
    esac
done

# 1. Load Environment, passing through any non-cleanup arguments
source "$(dirname "$0")/env_setup.sh" "${ARGS[@]}"

if [[ "$DEEP_CLEAN" == "true" ]]; then
    echo "🧼 SCRUBBING THE CRUCIBLE: Deep Decontamination Initiated..."
    # Wipe all Build Artifacts
    if [[ -d "$HOST_OUTPUT_DIR" ]]; then
        echo "🗑️  Removing all artifacts from $HOST_OUTPUT_DIR..."
        rm -rf "${HOST_OUTPUT_DIR:?}"/build_*
    fi
    # Docker Housekeeping
    echo "🐳 Pruning Docker builder cache..."
    docker container prune -f
    docker image prune -f
    echo "✨ Crucible scrubbed."
else
    # 2. Standard Slag Removal Logic
    KEEP=3
    echo "🧹 Cleaning the Slag (Target: $HOST_OUTPUT_DIR)..."
    if [[ -d "$HOST_OUTPUT_DIR" ]] && [[ "$HOST_OUTPUT_DIR" != "/" ]]; then
        BUILDS=$(find "${HOST_OUTPUT_DIR}" -maxdepth 1 -type d -name "build_*" | sort -r)
        BUILD_COUNT=$(echo "$BUILDS" | grep -c "build_" || echo 0)
        if [[ "$BUILD_COUNT" -gt "$KEEP" ]]; then
            echo "♻️  Found $BUILD_COUNT builds. Keeping the $KEEP most recent."
            echo "$BUILDS" | sed "1,${KEEP}d" | xargs -r rm -rf
            echo "✅ Routine cleanup complete."
        else
            echo "✨ Minimal slag detected ($BUILD_COUNT/$KEEP). No cleanup needed."
        fi
    else
        echo "⚠️  Valid Dist directory not found at $HOST_OUTPUT_DIR."
    fi
fi