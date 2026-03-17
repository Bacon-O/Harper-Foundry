#!/bin/bash
set -e

# ==============================================================================
#  HARPER FOUNDRY: KERNEL.ORG SOURCE PLUGIN
# ==============================================================================
# Downloads vanilla kernel source from kernel.org (upstream, no patches)
# This is ideal for minimal tinyconfig builds.
#
# Version Aliases:
#   - "latest" or "stable": Latest stable kernel (6.11.8)
#   - "lts": Latest LTS kernel (6.1.x)
#   - "rc": Latest release candidate
#   - Specific version: "6.11.8", "6.10.5", etc.
#
# Args:
#   $1 - SOFTWARE_VERSION (e.g., "latest", "lts", "6.11.8")
#   $2 - BUILD_ROOT directory (where to download/extract)
#
# Returns:
#   Path to extracted kernel directory (stdout)
# ==============================================================================

# Resolve version alias to actual kernel version using kernel.org API
# Uses grep/sed for parsing (no jq dependency required)
resolve_software_version() {
    local version_spec="${1:-latest}"
    local api_url="https://www.kernel.org/releases.json"
    
    case "$version_spec" in
        latest|stable|"")
            # Query kernel.org API for latest stable release
            echo "[INFO] Querying kernel.org API for latest stable version..." >&2
            local version
            version=$(curl -s "$api_url" 2>/dev/null | grep -A2 latest_stable | grep version | head -n1 | sed 's/.*"version": "\([^"]*\)".*/\1/')
            
            if [[ -z "$version" ]]; then
                echo "[WARN] API query failed, using fallback version 6.12.8" >&2
                echo "6.12.8"
            else
                echo "[INFO] Latest stable from kernel.org: $version" >&2
                echo "$version"
            fi
            ;;
        lts)
            # Query for latest LTS kernel (first longterm entry)
            echo "[INFO] Querying kernel.org API for latest LTS version..." >&2
            local version
            version=$(curl -s "$api_url" 2>/dev/null | grep -B1 '"version":' | grep -A1 '"moniker": "longterm"' | grep '"version":' | head -n1 | sed 's/.*"version": "\([^"]*\)".*/\1/')
            
            if [[ -z "$version" ]]; then
                echo "[WARN] API query failed, using fallback LTS version 6.12.8" >&2
                echo "6.12.8"
            else
                echo "[INFO] Latest LTS from kernel.org: $version" >&2
                echo "$version"
            fi
            ;;
        rc)
            # Query for latest mainline/RC kernel
            echo "[INFO] Querying kernel.org API for latest mainline/RC version..." >&2
            local version
            version=$(curl -s "$api_url" 2>/dev/null | grep -B1 '"version":' | grep -A1 '"moniker": "mainline"' | grep '"version":' | head -n1 | sed 's/.*"version": "\([^"]*\)".*/\1/')
            
            if [[ -z "$version" ]]; then
                echo "[WARN] API query failed, using fallback to latest stable" >&2
                resolve_software_version "latest"
            else
                echo "[INFO] Latest mainline from kernel.org: $version" >&2
                echo "$version"
            fi
            ;;
        *)
            # Assume it's a specific version string
            echo "$version_spec"
            ;;
    esac
}

SOFTWARE_VERSION=$(resolve_software_version "${1:-}")
BUILD_ROOT="${2:-.}"

echo "[INFO] kernel.org: Resolved version alias to: $SOFTWARE_VERSION" >&2

# Ensure build root exists
mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

# Determine kernel major version (6 from 6.12.71)
# kernel.org stores all kernels under /v6.x/, not /v6.12.x/
KERNEL_MAJOR="${SOFTWARE_VERSION%%.*}"
KERNEL_TARBALL="linux-${SOFTWARE_VERSION}.tar.xz"
KERNEL_EXTRACT_DIR="linux-${SOFTWARE_VERSION}"

echo "[INFO] Fetching official kernel.org source: linux-${SOFTWARE_VERSION}" >&2

# Check if already downloaded
if [[ ! -f "$KERNEL_TARBALL" ]]; then
    echo "[INFO] Downloading linux-${SOFTWARE_VERSION}.tar.xz from kernel.org..." >&2
    
    # Try to download with progress indicator
    # kernel.org stores all versions under /v{major}.x/ (e.g., /v6.x/)
    if ! wget -q --show-progress "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/${KERNEL_TARBALL}" 2>/dev/null; then
        echo "[ERROR] Failed to download from kernel.org (cdn.kernel.org)" >&2
        echo "[ERROR] URL: https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/${KERNEL_TARBALL}" >&2
        exit 1
    fi
else
    echo "[INFO] Found cached kernel tarball: $KERNEL_TARBALL" >&2
fi

# Extract if not already extracted
if [[ ! -d "$KERNEL_EXTRACT_DIR" ]]; then
    echo "[INFO] Extracting kernel source..." >&2
    tar xf "$KERNEL_TARBALL" || {
        echo "[ERROR] Failed to extract kernel tarball" >&2
        exit 1
    }
fi

# Verify extraction
if [[ ! -d "$KERNEL_EXTRACT_DIR" ]]; then
    echo "[ERROR] Kernel extraction failed: $KERNEL_EXTRACT_DIR not found" >&2
    exit 1
fi

echo "[INFO] Kernel source ready: $BUILD_ROOT/$KERNEL_EXTRACT_DIR" >&2
echo "$BUILD_ROOT/$KERNEL_EXTRACT_DIR"
