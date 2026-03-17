#!/bin/bash

# ==============================================================================
# Harper Foundry: Debian Trixie Kernel Release Trigger Plugin
# ==============================================================================
# Monitors published Debian trixie-backports linux source availability.
# The published source index is the only trigger signal used by this plugin.
#
# PLUGIN INTERFACE (all trigger plugins must implement):
#   <plugin>_trigger()            - Check if build is needed, export version info
#                                    Returns: 0=build needed, 1=no action
#   <plugin>_build_successful()   - Callback invoked when build succeeds
#   <plugin>_build_failed()       - Callback invoked when build fails
#
# Usage:
#   source ./scripts/plugins/triggers/runner.sh
#   
#   # Check if build needed
#   check_if_build_is_needed harper_deb13_kernel
#   if [[$? -eq 0 ]]; then
#       # Run build...
#       if build succeeded; then
#           build_successful harper_deb13_kernel
#       else
#           build_failed harper_deb13_kernel "error_info"
#       fi
#   fi
#
# Options:
#   --force   Skip version comparison and always trigger
#
# Environment:
#   REPO_ROOT - Set automatically if not provided
#
# ==============================================================================

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-.}"
VERSION_TRACKING_FILE="${VERSION_TRACKING_FILE:-$REPO_ROOT/version_tracking/harper_deb13_latest_kernel.txt}"
DEBIAN_BACKPORTS_SOURCES_URL="${DEBIAN_BACKPORTS_SOURCES_URL:-https://deb.debian.org/debian/dists/trixie-backports/main/source/Sources.xz}"
DEBIAN_SOURCE_PACKAGE="${DEBIAN_SOURCE_PACKAGE:-linux}"

normalize_tracked_version() {
    local tracked_version="${1:-}"

    if [[ -z "$tracked_version" ]]; then
        echo ""
        return 0
    fi

    tracked_version="${tracked_version#debian/}"
    echo "$tracked_version" | sed 's/_/~/g'
}

get_latest_published_backports_source_version() {
    local sources_content
    local latest_version=""
    local candidate_version

    sources_content=$(curl -fsSL "$DEBIAN_BACKPORTS_SOURCES_URL" | xz -dc)

    while IFS= read -r candidate_version; do
        [[ -z "$candidate_version" ]] && continue

        if [[ -z "$latest_version" ]] || dpkg --compare-versions "$candidate_version" gt "$latest_version"; then
            latest_version="$candidate_version"
        fi
    done < <(
        awk -v package_name="$DEBIAN_SOURCE_PACKAGE" '
            $1 == "Package:" {
                in_package = ($2 == package_name)
                next
            }

            in_package && $1 == "Version:" {
                print $2
            }
        ' <<< "$sources_content"
    )

    echo "$latest_version"
}

# ==============================================================================
# FUNCTION: harper_deb13_kernel_trigger
# ==============================================================================
# Checks if a new Debian kernel version is available and needs building
# This function ONLY detects - it does NOT execute builds
#
# Arguments:
#   --force   Skip version comparison and always indicate build is needed
#
# Exports:
#   DETECTED_SOFTWARE_VERSION - Published backports version (e.g., "6.18.12-1~bpo13+1")
#   DETECTED_BUILD_REASON   - Why build is needed ("new_version" or "forced")
#
# Returns:
#   0 - Build IS needed (new version detected or forced)
#   1 - Build NOT needed (version already built)
#
# ==============================================================================
harper_deb13_kernel_trigger() {
    local force_build=false
    
    # Parse arguments
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
    
    log_info "=== Debian Trixie Kernel Release Monitor ==="
    
    # ==========================================================================
    # STEP 1: Check Prerequisites
    # ==========================================================================
    
    log_info "Checking prerequisites..."
    
    if ! command -v curl &> /dev/null; then
        log_error "curl not found. Please install curl."
        return 1
    fi

    if ! command -v xz &> /dev/null; then
        log_error "xz not found. Please install xz-utils."
        return 1
    fi

    if ! command -v dpkg &> /dev/null; then
        log_error "dpkg not found. Debian version comparison is required for this trigger."
        return 1
    fi
    
    if [[ ! -f "$VERSION_TRACKING_FILE" ]]; then
        log_warn "Version tracking file not found at $VERSION_TRACKING_FILE"
        log_info "Initializing version tracking..."
        mkdir -p "$(dirname "$VERSION_TRACKING_FILE")"
        cat > "$VERSION_TRACKING_FILE" << 'EOF'
SOFTWARE_VERSION=6.11.8
LAST_BUILD_DATE=$(date +%Y-%m-%d_%R:%S_%Z)
BUILD_STATUS=initialized
SCHED_PRIORITY=1
EOF
    fi
    
    # ==========================================================================
    # STEP 2: Query Debian Backports for Latest Published Source
    # ==========================================================================

    log_info "Querying Debian backports source index for published linux versions..."
    log_info "Source index: $DEBIAN_BACKPORTS_SOURCES_URL"

    local latest_published_source_version
    latest_published_source_version=$(get_latest_published_backports_source_version || echo "")

    if [[ -z "$latest_published_source_version" ]]; then
        log_error "Failed to determine the latest published Debian backports source version"
        return 1
    fi

    log_ok "Latest published source version: $latest_published_source_version"
    log_ok "Tracking version to compare: $latest_published_source_version"

    # ==========================================================================
    # STEP 3: Load Last Successfully Compiled Version
    # ==========================================================================
    
    log_info "Loading last compiled version from $VERSION_TRACKING_FILE"
    
    # Source the tracking file
    # shellcheck disable=SC1090
    source "$VERSION_TRACKING_FILE"
    
    local last_compiled_version
    last_compiled_version=$(normalize_tracked_version "${SOFTWARE_VERSION:-unknown}")
    local last_build_date="${LAST_BUILD_DATE:-unknown}"
    local build_status="${BUILD_STATUS:-unknown}"
    # currenlty now used
    # local last_sched_priority="${SCHED_PRIORITY:-1}"
    
    log_ok "Last compiled version: $last_compiled_version"
    log_ok "Last build date: $last_build_date"
    log_ok "Last build status: $build_status"
    
    # ==========================================================================
    # STEP 4: Compare Versions and Determine if Build is Needed
    # ==========================================================================
    
    log_info "Comparing versions..."
    
    local build_needed=false
    local build_reason=""
    
    if [[ "$force_build" = true ]]; then
        log_warn "FORCE BUILD requested via --force flag"
        build_needed=true
        build_reason="forced"
    elif [[ "$latest_published_source_version" != "$last_compiled_version" ]]; then
        log_warn "New published version detected: $latest_published_source_version (previously: $last_compiled_version)"
        log_info "Triggering build for new kernel version"
        build_needed=true
        build_reason="new_version"
    elif [[ "$build_status" == "failed" ]] && [[ "$last_compiled_version" == "$latest_published_source_version" ]]; then
        log_warn "Previous build for version $last_compiled_version failed"
        log_warn "Will not retry until:"
        log_warn "   - a new version is detected"
        log_warn "   - BUILD_STATUS=retry is set"
        log_warn "   - version_tracking/harper_deb13_latest_kernel.txt is cleared"
    elif [[ "$build_status" == "retry" ]] && [[ "$last_compiled_version" == "$latest_published_source_version" ]]; then
        log_info "Previous build for version $last_compiled_version is marked for retry"
        log_info "Will retry this version: $last_compiled_version"
        build_needed=true
        build_reason="retry_failed_version"
    else
        # Same version - no action needed
        log_ok "Version $last_compiled_version already built"
        log_info "Will build automatically when new kernel version is released"
        build_needed=false
    fi
    
    # ==========================================================================
    # STEP 5: Return Build Status to Caller
    # ==========================================================================
    # This plugin ONLY detects if a build is needed - it does NOT execute builds
    # The caller (e.g., cron_example.sh) decides what to do based on exit code
    
    if [[ "$build_needed" = true ]]; then
        log_warn "Build needed for kernel $latest_published_source_version (reason: $build_reason)"
        log_info "Returning exit code 0 to indicate build is needed"
        
        # Export detected version for use by caller (e.g., in build_successful callback)
        export DETECTED_SOFTWARE_VERSION="$latest_published_source_version"
        export DETECTED_software_source_VERSION="$latest_published_source_version"
        export DETECTED_BUILD_REASON="$build_reason"
        
        return 0  # 0 = build needed
    else
        log_ok "No action needed. Latest version already built."
        log_info "Returning exit code 1 to indicate no build needed"
        return 1  # non-zero = no build needed
    fi
}

# ==============================================================================
# FUNCTION: harper_deb13_kernel_build_successful
# ==============================================================================
# Callback invoked when build completes successfully
# Updates version tracking file with the newly built kernel version
#
# Arguments:
#   None (uses exported DETECTED_SOFTWARE_VERSION from trigger function)
#
# Returns:
#   0 - Tracking file updated successfully
#   1 - Error updating tracking file
#
# ==============================================================================
harper_deb13_kernel_build_successful() {
    log_info "=== Build Success Callback ==="
    
    if [[ -z "${DETECTED_SOFTWARE_VERSION:-}" ]]; then
        log_error "DETECTED_SOFTWARE_VERSION not set. Did you run the trigger check first?"
        return 1
    fi
    
    log_ok "Updating version tracking for kernel $DETECTED_SOFTWARE_VERSION"
    
    # Update version tracking file
    cat > "$VERSION_TRACKING_FILE" << EOF
SOFTWARE_VERSION=$DETECTED_SOFTWARE_VERSION
LAST_BUILD_DATE=$(date -u +%Y-%m-%d)
BUILD_STATUS=success
EOF
    
    log_ok "Version tracking updated: $VERSION_TRACKING_FILE"
    log_ok "Next trigger check will compare against version $DETECTED_SOFTWARE_VERSION"
    
    return 0
}

# ==============================================================================
# FUNCTION: harper_deb13_kernel_build_failed
# ==============================================================================
# Callback invoked when build fails
# Updates tracking file to record the failure (optional)
#
# Arguments:
#   $1 - (optional) Error message or exit code from build
#
# Returns:
#   0 - Failure recorded
#
# ==============================================================================
harper_deb13_kernel_build_failed() {
    local error_info="${1:-unknown}"
    
    log_info "=== Build Failure Callback ==="
    log_error "Build failed for kernel ${DETECTED_SOFTWARE_VERSION:-unknown}: $error_info"
    
    # Optionally update tracking file to record failure
    # This prevents retrying the same failed version repeatedly
    # Uncomment if you want to skip failed versions:
    #
    cat > "$VERSION_TRACKING_FILE" << EOF
SOFTWARE_VERSION=${DETECTED_SOFTWARE_VERSION:-unknown}
LAST_BUILD_DATE=$(date -u +%Y-%m-%d)
BUILD_STATUS=failed
BUILD_ERROR=$error_info
EOF
    
    log_warn "Version tracking NOT updated - will retry this version on next trigger check"
    
    return 0
}