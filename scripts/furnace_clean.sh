#!/bin/bash
set -e

# 1. Load Environment
source "$(dirname "$0")/env_setup.sh" "$@"

# 2. Slag Removal Logic
KEEP=3
echo "🧹 Cleaning the Slag (Target: $HOST_DIST_BASE)..."

if [ -d "$HOST_DIST_BASE" ]; then
    # Filter for directories matching the build pattern
    BUILD_COUNT=$(ls -1d "${HOST_DIST_BASE}"/build_*/ 2>/dev/null | wc -l)
    
    if [ "$BUILD_COUNT" -gt "$KEEP" ]; then
        echo "♻️  Found $BUILD_COUNT builds. Keeping the $KEEP most recent."
        ls -1dt "${HOST_DIST_BASE}"/build_*/ | tail -n +$((KEEP + 1)) | xargs rm -rf
        echo "✅ Routine cleanup complete."
    else
        echo "✨ Minimal slag detected. No cleanup needed."
    fi
else
    echo "⚠️  Dist directory not found at $HOST_DIST_BASE."
fi