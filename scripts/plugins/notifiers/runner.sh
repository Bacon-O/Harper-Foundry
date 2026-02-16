#!/bin/bash

# ==============================================================================
# Harper Foundry: Notifiers Plugin Runner
# ==============================================================================
# Main dispatcher for notification/monitoring integrations
# Allows integration with CheckMK, Prometheus, Slack, email, etc.
#
# Usage:
#   source ./scripts/plugins/notifiers/runner.sh
#   notify <notifier_name> [options...]
#
# Supported Notifiers:
#   - harper_checkmk    : CheckMK local check integration for Harper builds
#   - (add more as needed)
#
# ==============================================================================

set -euo pipefail

PLUGINS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$PLUGINS_DIR/../../.." && pwd)}"

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
# FUNCTION: notify
# ==============================================================================
# Main dispatcher function. Routes to appropriate notifier plugin.
#
# Arguments:
#   $1 - notifier_name (e.g., "harper_checkmk")
#   $2+ - options to pass to the plugin
#
# Returns:
#   Notifier-specific exit code (often 0=OK, 1=WARNING, 2=CRITICAL)
#
# ==============================================================================
notify() {
    local tool_name="${1:-}"
    shift || true
    
    if [ -z "$tool_name" ]; then
        log_error "No notifier name specified"
        log_info "Usage: notify <notifier_name> [options...]"
        log_info ""
        log_info "Available notifiers:"
        for plugin in "$PLUGINS_DIR"/*.sh; do
            if [ "$plugin" != "$PLUGINS_DIR/runner.sh" ]; then
                local plugin_name=$(basename "$plugin" .sh)
                log_info "  - $plugin_name"
            fi
        done
        return 1
    fi
    
    local plugin_file="$PLUGINS_DIR/${tool_name}.sh"
    
    if [ ! -f "$plugin_file" ]; then
        log_error "Notifier plugin not found: $tool_name"
        log_error "Expected: $plugin_file"
        return 1
    fi
    
    log_info "Loading notifier: $tool_name"
    
    # Source and execute the plugin
    # shellcheck disable=SC1090
    if source "$plugin_file"; then
        # Call the plugin's main function if it exists
        if declare -f "${tool_name}_check" > /dev/null; then
            "${tool_name}_check" "$@"
            return $?
        else
            log_error "Plugin $tool_name does not define ${tool_name}_check function"
            return 1
        fi
    else
        log_error "Failed to load notifier plugin: $tool_name"
        return 1
    fi
}

# Export functions for use in subshells
export -f log_info log_ok log_warn log_error
export -f notify
