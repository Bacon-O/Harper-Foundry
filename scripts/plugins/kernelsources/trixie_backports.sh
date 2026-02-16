#!/bin/bash
set -e

# ==============================================================================
#  HARPER FOUNDRY: DEBIAN TRIXIE BACKPORTS SOURCE PLUGIN
# ==============================================================================
# Fetches kernel source from Debian Trixie Backports repository.
# This provides newer kernels while maintaining Debian patch compatibility.
#
# Version Aliases:
#   - "latest": Latest kernel from trixie-backports (no version constraint)
#   - "stable": Latest stable from trixie-backports (same as latest)
#   - "lts": LTS kernels from trixie-backports
#   - "rc": Release candidates if available
#   - Specific version: "6.11.8", "6.10.5", etc.
#
# Requirements:
#   - apt-get must be available
#   - /etc/apt/sources.list must include 'deb' and 'deb-src' for trixie-backports
#   - Run 'apt-get update' after configuring backports
#
# Configuration:
#   Add to /etc/apt/sources.list:
#   deb http://deb.debian.org/debian trixie-backports main
#   deb-src http://deb.debian.org/debian trixie-backports main
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
            # Latest available from trixie-backports - no version constraint
            echo ""
            ;;
        lts)
            # LTS kernel pattern
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

if [ -z "$VERSION_CONSTRAINT" ]; then
    echo "[INFO] Fetching latest available Trixie Backports kernel source..." >&2
else
    echo "[INFO] Fetching Trixie Backports kernel source matching: $VERSION_CONSTRAINT" >&2
fi

# Check if apt-get is available
if ! command -v apt-get &>/dev/null; then
    echo "[ERROR] apt-get not found. Trixie Backports plugin requires Debian/Ubuntu." >&2
    exit 1
fi

# Verify deb-src is configured for trixie-backports
if ! grep -q "deb-src.*trixie-backports" /etc/apt/sources.list* 2>/dev/null; then
    echo "[WARNING] No 'deb-src' entry found for trixie-backports in /etc/apt/sources.list" >&2
    echo "[WARNING] Add the following line to /etc/apt/sources.list or a file in /etc/apt/sources.list.d/:" >&2
    echo "[WARNING]   deb-src http://deb.debian.org/debian trixie-backports main" >&2
    echo "[WARNING] Then run: apt-get update" >&2
fi

# Ensure package indices are up-to-date
echo "[INFO] Updating package indices..." >&2
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
        sudo -n apt-get update 2>&1 | grep -E "(Reading|Building)" >&2 || true
    else
        echo "[ERROR] sudo not available to run apt-get update" >&2
        exit 1
    fi
else
    apt-get update 2>&1 | grep -E "(Reading|Building)" >&2 || true
fi

# Pull kernel source from trixie-backports repository
# The -t flag targets the backports suite specifically
if ! apt-get source -t trixie-backports "linux${VERSION_CONSTRAINT}" 1>&2; then
    echo "[ERROR] Failed to fetch kernel source from trixie-backports" >&2
    echo "[ERROR] Hint: Ensure deb-src for trixie-backports is configured" >&2
    echo "[ERROR] Hint: Run 'apt-get update' after adding deb-src lines" >&2
    echo "[ERROR] Hint: Verify the 'linux' source package exists in trixie-backports" >&2
    exit 1
fi

# Find the extracted directory (apt-get source creates linux-* directory)
KERNEL_DIR=$(find . -maxdepth 1 -type d -name "linux-*" | head -1)

if [ -z "$KERNEL_DIR" ] || [ ! -d "$KERNEL_DIR" ]; then
    echo "[ERROR] Kernel source extraction failed: no linux-* directory found" >&2
    exit 1
fi

echo "[INFO] Trixie Backports kernel source ready: $BUILD_ROOT/${KERNEL_DIR#./}" >&2
echo "$BUILD_ROOT/${KERNEL_DIR#./}"
