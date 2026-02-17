#!/bin/bash

# ==============================================================================
# Harper Foundry: Trigger System Plugin Runner
# ==============================================================================
# Main dispatcher for trigger plugins. Allows flexible trigger backends
# for various upstream sources and build strategies.
#
# Usage:
#   $(source ./scripts/plugins/triggers/runner.sh)
#   check_if_build_is_needed <trigger_type> [options...]
#
# Supported Trigger Types:
#   - harper_deb13_kernel    : Debian Trixie Backports kernel releases
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
# FUNCTION: check_if_build_is_needed
# ==============================================================================
# Main dispatcher function. Routes to appropriate trigger plugin.
#
# Arguments:
#   $1 - trigger_type (e.g., "harper_deb13_kernel")
#   $2+ - options to pass to the plugin
#
# Returns:
#   0 if build is needed (new version detected)
#   1 if no action needed or error occurred
#
# ==============================================================================
check_if_build_is_needed() {
    local trigger_type="${1:-}"
    shift || true
    
    if [ -z "$trigger_type" ]; then
        log_error "No trigger type specified"
        log_info "Usage: check_if_build_is_needed <trigger_type> [options...]"
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

# ==============================================================================
# FUNCTION: build_successful
# ==============================================================================
# Callback invoked when a build completes successfully
# Routes to the plugin's build_successful callback to update tracking
#
# Arguments:
#   $1 - trigger_type (e.g., "harper_deb13_kernel")
#   $2+ - optional arguments to pass to plugin callback
#
# Returns:
#   Plugin callback's return code
#
# ==============================================================================
build_successful() {
    local trigger_type="${1:-}"
    shift || true
    
    if [ -z "$trigger_type" ]; then
        log_error "No trigger type specified for build_successful callback"
        return 1
    fi
    
    local callback_func="${trigger_type}_build_successful"
    
    if declare -f "$callback_func" > /dev/null; then
        "$callback_func" "$@"
        return $?
    else
        log_warn "Plugin $trigger_type does not define $callback_func function"
        log_warn "Skipping success callback"
        return 0
    fi
}

# ==============================================================================
# FUNCTION: build_failed
# ==============================================================================
# Callback invoked when a build fails
# Routes to the plugin's build_failed callback to handle failure
#
# Arguments:
#   $1 - trigger_type (e.g., "harper_deb13_kernel")
#   $2+ - optional error info to pass to plugin callback
#
# Returns:
#   Plugin callback's return code
#
# ==============================================================================
build_failed() {
    local trigger_type="${1:-}"
    shift || true
    
    if [ -z "$trigger_type" ]; then
        log_error "No trigger type specified for build_failed callback"
        return 1
    fi
    
    local callback_func="${trigger_type}_build_failed"
    
    if declare -f "$callback_func" > /dev/null; then
        "$callback_func" "$@"
        return $?
    else
        log_warn "Plugin $trigger_type does not define $callback_func function"
        log_warn "Skipping failure callback"
        return 0
    fi
}

# Export functions for use in subshells
export -f log_info log_ok log_warn log_error
export -f check_if_build_is_needed
export -f build_successful
export -f build_failed
