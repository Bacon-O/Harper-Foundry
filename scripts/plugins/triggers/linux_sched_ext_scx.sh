#!/bin/bash

# ==============================================================================
# Harper Foundry: sched-ext/scx Release Trigger Plugin
# ==============================================================================
# Monitors sched-ext/scx upstream releases on GitHub.
#
# PLUGIN INTERFACE (all trigger plugins must implement):
#   <plugin>_trigger()            - Check if build is needed, export version info
#                                    Returns: 0=build needed, 1=no action
#   <plugin>_build_successful()   - Callback invoked when build succeeds
#   <plugin>_build_failed()       - Callback invoked when build fails
#
# Options:
#   --force   Skip version comparison and always trigger
#
# ==============================================================================

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-.}"
VERSION_TRACKING_FILE="${VERSION_TRACKING_FILE:-$REPO_ROOT/version_tracking/linux_sched-ext_scx_latest.txt}"
SCX_RELEASES_API_URL="${SCX_RELEASES_API_URL:-https://api.github.com/repos/sched-ext/scx/releases/latest}"
SCX_REPO_URL="${SCX_REPO_URL:-https://github.com/sched-ext/scx.git}"

get_latest_scx_release_tag() {
    local latest_tag=""

    latest_tag=$(curl -fsSL "$SCX_RELEASES_API_URL" 2>/dev/null \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' \
        | head -n1)

    if [[ -n "$latest_tag" ]]; then
        echo "$latest_tag"
        return 0
    fi

    log_warn "GitHub release API lookup failed, falling back to remote tag discovery"
    latest_tag=$(git ls-remote --tags --refs "$SCX_REPO_URL" 2>/dev/null \
        | awk '{sub("refs/tags/", "", $2); print $2}' \
        | sort -V \
        | tail -n1)

    if [[ -z "$latest_tag" ]]; then
        return 1
    fi

    echo "$latest_tag"
}

# ==============================================================================
# FUNCTION: linux_sched_ext_scx_trigger
# ==============================================================================
linux_sched_ext_scx_trigger() {
    local force_build=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                force_build=true
                shift
                ;;
            *)
                log_warn "Unknown option: $1"
                shift
                ;;
        esac
    done

    log_info "=== sched-ext/scx Release Monitor ==="
    log_info "Checking prerequisites..."

    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl not found. Please install curl."
        return 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        log_error "git not found. Please install git."
        return 1
    fi

    if [[ ! -f "$VERSION_TRACKING_FILE" ]]; then
        log_warn "Version tracking file not found at $VERSION_TRACKING_FILE"
        log_info "Initializing version tracking..."
        mkdir -p "$(dirname "$VERSION_TRACKING_FILE")"
        cat > "$VERSION_TRACKING_FILE" << 'EOF'
SOFTWARE_VERSION=none
LAST_BUILD_DATE=never
BUILD_STATUS=initialized
EOF
    fi

    local latest_release_tag
    latest_release_tag=$(get_latest_scx_release_tag || echo "")

    if [[ -z "$latest_release_tag" ]]; then
        log_error "Failed to determine latest sched-ext/scx release tag"
        return 1
    fi

    log_ok "Latest upstream sched-ext/scx release: $latest_release_tag"

    # shellcheck disable=SC1090
    source "$VERSION_TRACKING_FILE"

    local last_compiled_version="${SOFTWARE_VERSION:-none}"
    local build_status="${BUILD_STATUS:-unknown}"

    log_ok "Last compiled version: $last_compiled_version"
    log_ok "Last build status: $build_status"

    local build_needed=false
    local build_reason=""

    if [[ "$force_build" = true ]]; then
        log_warn "FORCE BUILD requested via --force flag"
        build_needed=true
        build_reason="forced"
    elif [[ "$latest_release_tag" != "$last_compiled_version" ]]; then
        log_warn "New release detected: $latest_release_tag (previously: $last_compiled_version)"
        build_needed=true
        build_reason="new_version"
    elif [[ "$build_status" == "retry" ]] && [[ "$last_compiled_version" == "$latest_release_tag" ]]; then
        log_info "Current version marked for retry: $last_compiled_version"
        build_needed=true
        build_reason="retry_failed_version"
    else
        log_ok "No action needed. Latest version already built."
    fi

    if [[ "$build_needed" = true ]]; then
        export DETECTED_SOFTWARE_VERSION="$latest_release_tag"
        export DETECTED_BUILD_REASON="$build_reason"
        log_warn "Build needed for sched-ext/scx $latest_release_tag (reason: $build_reason)"
        return 0
    fi

    return 1
}

# ==============================================================================
# FUNCTION: linux_sched_ext_scx_build_successful
# ==============================================================================
linux_sched_ext_scx_build_successful() {
    log_info "=== Build Success Callback ==="

    if [[ -z "${DETECTED_SOFTWARE_VERSION:-}" ]]; then
        log_error "DETECTED_SOFTWARE_VERSION not set. Did you run the trigger check first?"
        return 1
    fi

    cat > "$VERSION_TRACKING_FILE" << EOF
SOFTWARE_VERSION=$DETECTED_SOFTWARE_VERSION
LAST_BUILD_DATE=$(date -u +%Y-%m-%d)
BUILD_STATUS=success
EOF

    log_ok "Version tracking updated: $VERSION_TRACKING_FILE"
    return 0
}

# ==============================================================================
# FUNCTION: linux_sched_ext_scx_build_failed
# ==============================================================================
linux_sched_ext_scx_build_failed() {
    local error_info="${1:-unknown}"

    log_info "=== Build Failure Callback ==="
    log_error "Build failed for sched-ext/scx ${DETECTED_SOFTWARE_VERSION:-unknown}: $error_info"

    cat > "$VERSION_TRACKING_FILE" << EOF
SOFTWARE_VERSION=${DETECTED_SOFTWARE_VERSION:-unknown}
LAST_BUILD_DATE=$(date -u +%Y-%m-%d)
BUILD_STATUS=failed
BUILD_ERROR=$error_info
EOF

    return 0
}
