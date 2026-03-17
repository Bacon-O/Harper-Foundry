#!/bin/bash

# ==============================================================================
#  HARPER FOUNDRY: SOURCE FETCHER PLUGIN RUNNER
# ==============================================================================
# This plugin system maps SOFTWARE_SOURCE to specific fetcher
# implementations. It allows flexible source acquisition (kernel.org, Debian
# source, custom, etc.) without hardcoding logic in build scripts.
#
# Usage:
#   source "$(dirname "$0")/runner.sh"
#   KERNEL_DIR=$(fetch_software_source "kernel.org" "6.11.8")
#   cd "$KERNEL_DIR"
#   make tinyconfig
#
# Supported sources:
#   - kernel.org      : Official kernel.org sources (vanilla upstream)
#   - debian          : Debian apt-get source (includes patches)
#   - debian/trixie-backports : Debian Trixie Backports (newer kernels with Debian patches)
#   - sched-ext/scx   : GitHub release tags from sched-ext/scx
#   - custom or none  : User implements custom logic in their ci-build script
# ==============================================================================

# Ensure we are in the source fetcher plugin directory
SOURCE_FETCHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SOURCE_FETCHER_DIR/../../.." && pwd)"

# ============================================================================
#  MAIN FUNCTION: fetch_software_source
# ============================================================================
# Maps SOFTWARE_SOURCE to appropriate plugin and returns kernel directory path
#
# Version Aliases:
#   Each plugin interprets version specs based on what's available from its source:
#   
#   kernel.org:
#     "latest" / ""     → 6.11.8 (latest stable)
#     "stable"          → 6.11.8
#     "lts"             → 6.1.112 (latest LTS)
#     "rc"              → latest release candidate
#     "6.11.8"          → pins to exact version
#   
#   debian / trixie-backports:
#     "latest" / ""     → no version constraint (newest available)
#     "stable"          → same as latest
#     "lts"             → LTS kernels if available
#     "rc"              → release candidates if available
#     "6.11.8"          → pins to exact version
#
# Args:
#   $1 - SOFTWARE_SOURCE value (e.g., "kernel.org", "debian", "debian/trixie-backports", "sched-ext/scx")
#   $2 - SOFTWARE_VERSION (alias or specific version)
#   $3 - BUILD_ROOT directory (optional, defaults to current dir)
#
# Returns:
#   Path to fetched source directory (stdout)
#   Exit code 0 on success, non-zero on failure
#
# Examples:
#   # Get latest/default from kernel.org (6.11.8)
#   KERNEL_DIR=$(fetch_software_source "kernel.org")
#
#   # Always get newest from trixie-backports
#   KERNEL_DIR=$(fetch_software_source "debian/trixie-backports" "latest")
#
#   # Get LTS kernel from Debian
#   KERNEL_DIR=$(fetch_software_source "debian" "lts")
#
#   # Pin to specific version
#   KERNEL_DIR=$(fetch_software_source "kernel.org" "6.10.5")
# ============================================================================
fetch_software_source() {
    local source_type="${1:-kernel.org}"
    local SOFTWARE_VERSION="${2:-6.11.8}"
    local build_root="${3:-.}"
    
    # Normalize source type to lowercase
    source_type=$(echo "$source_type" | tr '[:upper:]' '[:lower:]')
    
    # Convert slash notation to hyphen for file lookup (e.g., "debian/trixie-backports" -> "debian-trixie-backports")
    local source_file="${source_type//\//-}"
    
    # Check for custom plugin first (in scripts/scripts.d/plugins/source_fetcher/) - takes precedence
    local custom_plugin="${REPO_ROOT}/scripts/scripts.d/plugins/source_fetcher/${source_file}.sh"
    if [[ -x "$custom_plugin" ]]; then
        log_software_source "INFO" "Using custom source fetcher: $source_file"
        "$custom_plugin" "$SOFTWARE_VERSION" "$build_root"
        return $?
    fi
    
    case "$source_type" in
        kernel.org|kernel-org)
            # Use official kernel.org vanilla sources
            "$SOURCE_FETCHER_DIR/kernel_org.sh" "$SOFTWARE_VERSION" "$build_root"
            ;;
        debian|debian-source)
            # Use Debian apt-get source (includes Debian patches)
            "$SOURCE_FETCHER_DIR/debian.sh" "$SOFTWARE_VERSION" "$build_root"
            ;;
        debian/trixie-backports|trixie-backports|trixie)
            # Use Debian Trixie Backports for newer kernels with Debian patches
            "$SOURCE_FETCHER_DIR/trixie_backports.sh" "$SOFTWARE_VERSION" "$build_root"
            ;;
        sched-ext/scx|sched-ext-scx|scx|linux_sched-ext-scx)
            # Use sched-ext/scx GitHub release tags
            "$SOURCE_FETCHER_DIR/linux_sched-ext-scx.sh" "$SOFTWARE_VERSION" "$build_root"
            ;;
        custom|none|"")
            # Skip automatic source fetching
            # User should implement their own logic in ci-build script
            echo "[INFO] SOFTWARE_SOURCE is set to '$source_type'" >&2
            echo "[INFO] Skipping automatic kernel fetch - implement custom logic in ci-build" >&2
            return 0
            ;;
        *)
            echo "[ERROR] Unknown SOFTWARE_SOURCE type: '$source_type'" >&2
            echo "[ERROR] Supported types: kernel.org, debian, debian/trixie-backports, sched-ext/scx, custom, none" >&2
            echo "[ERROR] Custom sources can be added to: scripts/scripts.d/plugins/source_fetcher/" >&2
            return 1
            ;;
    esac
}

# ============================================================================
#  HELPER: Check if plugin exists and is executable
# ============================================================================
check_plugin_exists() {
    local plugin_file="$SOURCE_FETCHER_DIR/$1.sh"
    if [[ ! -x "$plugin_file" ]]; then
        echo "[ERROR] Plugin not found or not executable: $plugin_file" >&2
        return 1
    fi
    return 0
}

# ============================================================================
#  HELPER: Log function for consistency
# ============================================================================
log_software_source() {
    local level="$1"
    shift
    echo "[$level] $*" >&2
}

# Export functions so they're available in subshells
export -f fetch_software_source
export -f check_plugin_exists
export -f log_software_source
export SOURCE_FETCHER_DIR
export REPO_ROOT
