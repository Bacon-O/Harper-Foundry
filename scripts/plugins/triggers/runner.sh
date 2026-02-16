#!/bin/bash

# ==============================================================================
# Harper Foundry: Trigger System Plugin Runner
# ==============================================================================
# Main dispatcher for trigger plugins. Allows flexible trigger backends
# for various upstream sources and build strategies.
#
# Usage:
#   $(source ./scripts/plugins/triggers/runner.sh)
#   trigger_build <trigger_type> [options...]
#
# Supported Trigger Types:
#   - alloy_deb13_kernel    : Debian Trixie Backports kernel releases
#   - (add more as needed)
#
# ==============================================================================

set -euo pipefail

PLUGINS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-.}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC}   $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}     $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}   $1"; }
log_error() { echo -e "${RED}[ERROR]${NC}  $1"; }

# ==============================================================================
# FUNCTION: trigger_build
# ==============================================================================
# Main dispatcher function. Routes to appropriate trigger plugin.
#
# Arguments:
#   $1 - trigger_type (e.g., "alloy_deb13_kernel")
#   $2+ - options to pass to the plugin
#
# Returns:
#   0 if no action needed or build triggered successfully
#   1 if error occurred
#
# ==============================================================================
trigger_build() {
    local trigger_type="${1:-}"
    shift || true
    
    if [ -z "$trigger_type" ]; then
        log_error "No trigger type specified"
        log_info "Usage: trigger_build <trigger_type> [options...]"
        log_info ""
        log_info "Available trigger types:"
        for plugin in "$PLUGINS_DIR"/*.sh; do
            if [ "$plugin" != "$PLUGINS_DIR/runner.sh" ]; then
                local plugin_name
                plugin_name=$(basename "$plugin" .sh)
                log_info "  - $plugin_name"
            fi
        done
        return 1
    fi
    
    local plugin_file="$PLUGINS_DIR/${trigger_type}.sh"
    
    if [ ! -f "$plugin_file" ]; then
        log_error "Trigger plugin not found: $trigger_type"
        log_error "Expected: $plugin_file"
        return 1
    fi
    
    log_info "Loading trigger plugin: $trigger_type"
    
    # Source and execute the plugin
    # shellcheck disable=SC1090
    if source "$plugin_file"; then
        # Call the plugin's main function if it exists
        if declare -f "${trigger_type}_trigger" > /dev/null; then
            "${trigger_type}_trigger" "$@"
            return $?
        else
            log_error "Plugin $trigger_type does not define ${trigger_type}_trigger function"
            return 1
        fi
    else
        log_error "Failed to load trigger plugin: $trigger_type"
        return 1
    fi
}

# Export functions for use in subshells
export -f log_info log_ok log_warn log_error
export -f trigger_build
