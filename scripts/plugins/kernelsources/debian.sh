#!/bin/bash
set -e

# ==============================================================================
#  HARPER FOUNDRY: DEBIAN SOURCE PLUGIN
# ==============================================================================
# Fetches kernel source using 'apt-get source' (includes Debian patches)
# This is ideal for full Harper builds with Debian customizations.
#
# Version Aliases:
#   - "latest": Latest kernel available in Debian repos (no version constraint)
#   - "stable": Latest stable (same as latest for Debian)
#   - "lts": LTS kernels if available in Debian
#   - "rc": Release candidates if available
#   - Specific version: "6.11.8", "6.10.5", etc.
#
# Requirements:
#   - apt-get must be available
#   - Debian repositories configured
#   - 'deb-src' lines in /etc/apt/sources.list or sources.list.d/
#
# Args:
#   $1 - KERNEL_VERSION (e.g., "latest", "lts", "6.11.8")
#   $2 - BUILD_ROOT directory (where to download/extract)
#
# Returns:
#   Path to extracted kernel directory (stdout)
# ==============================================================================

# Resolve version alias to apt-get version constraint
resolve_version_constraint() {
    local version_spec="${1:-latest}"
    
    case "$version_spec" in
        latest|stable|"")
            # Latest available - no version constraint
            echo ""
            ;;
        lts)
            # LTS kernel pattern (6.1, 6.6, 5.15, 5.10 are LTS)
            # Try to find available LTS, otherwise fall back to latest
            echo "*lts*"
            ;;
        rc)
            # Release candidate pattern
            echo "*rc*"
            ;;
        *)
            # Assume it's a specific version string
            echo "=${version_spec}*"
            ;;
    esac
}

VERSION_CONSTRAINT=$(resolve_version_constraint "${1:-}")
BUILD_ROOT="${2:-.}"

# Ensure build root exists
mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

if [[ -z "$VERSION_CONSTRAINT" ]]; then
    echo "[INFO] Fetching latest available Debian kernel source..." >&2
else
    echo "[INFO] Fetching Debian kernel source matching: $VERSION_CONSTRAINT" >&2
fi

# Check if apt-get is available
if ! command -v apt-get &>/dev/null; then
    echo "[ERROR] apt-get not found. Debian source plugin requires Debian/Ubuntu." >&2
    return 1
fi

# Pull kernel source (will extract to linux-* directory)
if ! apt-get source "linux${VERSION_CONSTRAINT}" 1>&2; then
    echo "[ERROR] Failed to fetch Debian kernel source" >&2
    echo "[ERROR] Hint: Ensure 'deb-src' lines are in /etc/apt/sources.list" >&2
    echo "[ERROR] Hint: Run 'apt-get update' after adding deb-src lines" >&2
    echo "[ERROR] Hint: Verify the 'linux' source package exists in the configured suite" >&2
    return 1
fi

# Find the extracted directory (apt-get source creates linux-* or linux-image-* dir)
KERNEL_DIR=$(find . -maxdepth 1 -type d -name "linux-*" | head -1)

if [[ -z "$KERNEL_DIR" ]] || [[ ! -d "$KERNEL_DIR" ]]; then
    echo "[ERROR] Kernel source extraction failed: no linux-* directory found" >&2
    return 1
fi

echo "[INFO] Debian kernel source ready: $BUILD_ROOT/${KERNEL_DIR#./}" >&2
echo "$BUILD_ROOT/${KERNEL_DIR#./}"
