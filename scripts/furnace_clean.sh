#!/bin/bash
set -e

# 1. Load Environment
source "$(dirname "$0")/env_setup.sh" "$@"

# 2. Slag Removal Logic
KEEP=3
echo "🧹 Cleaning the Slag (Target: $HOST_DIST_BASE)..."

if [ -d "$HOST_DIST_BASE" ] && [ "$HOST_DIST_BASE" != "/" ]; then
    # Use 'find' for more robust listing and avoid 'ls' parsing issues
    BUILDS=$(find "${HOST_DIST_BASE}" -maxdepth 1 -type d -name "build_*" | sort -r)
    BUILD_COUNT=$(echo "$BUILDS" | grep -c "build_" || echo 0)
    
    if [ "$BUILD_COUNT" -gt "$KEEP" ]; then
        echo "♻️  Found $BUILD_COUNT builds. Keeping the $KEEP most recent."
        # Drop the first $KEEP items, then remove the rest
        echo "$BUILDS" | sed "1,${KEEP}d" | xargs -r rm -rf
        echo "✅ Routine cleanup complete."
    else
        echo "✨ Minimal slag detected ($BUILD_COUNT/$KEEP). No cleanup needed."
    fi
else
    echo "⚠️  Valid Dist directory not found at $HOST_DIST_BASE."
fi