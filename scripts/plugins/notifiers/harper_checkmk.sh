#!/bin/bash

# ==============================================================================
# Harper Foundry: CheckMK Local Check Plugin
# ==============================================================================
# Monitors Harper kernel build status and reports to CheckMK
#
# Usage:
#   source ./scripts/plugins/notifiers/harper_checkmk.sh
#   harper_checkmk_check [--profile <profile_name>]
#
# Options:
#   --profile    Build profile to monitor (default: harper_deb13)
#
# Exit Codes (CheckMK standard):
#   0 - OK       : New build successful or no changes
#   1 - WARNING  : Build succeeded but BORE patch failed to apply
#   2 - CRITICAL : Build failed completely
#   3 - UNKNOWN  : Unable to determine status
#
# Notification Logic:
#   - New version built: Notify once (OK status)
#   - BORE failed: WARNING until manually cleared or new build with BORE
#   - Build failed: CRITICAL until fixed
#
# Environment:
#   REPO_ROOT - Set automatically if not provided
#
# ==============================================================================

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-.}"
NOTIFICATION_STATE_DIR="$REPO_ROOT/version_tracking/.notification_state"

# ==============================================================================
# FUNCTION: harper_checkmk_check
# ==============================================================================
# Main CheckMK check function for Harper builds
#
# Arguments:
#   --profile <name>  Build profile to monitor (default: harper_deb13)
#
# Returns:
#   0=OK, 1=WARNING, 2=CRITICAL, 3=UNKNOWN
#
# ==============================================================================
harper_checkmk_check() {
    local profile="harper_deb13"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                profile="$2"
                shift 2
                ;;
            *)
                log_warn "Unknown option: $1"
                shift
                ;;
        esac
    done
    
    local version_file="$REPO_ROOT/version_tracking/${profile}_latest_kernel.txt"
    local notify_state_file="$NOTIFICATION_STATE_DIR/${profile}_notified.txt"
    
    # Create notification state directory
    mkdir -p "$NOTIFICATION_STATE_DIR"
    
    # ==========================================================================
    # STEP 1: Check if version tracking file exists
    # ==========================================================================
    
    if [ ! -f "$version_file" ]; then
        echo "3 Harper_Build_${profile} - UNKNOWN: Version tracking file not found at $version_file"
        return 3
    fi
    
    # ==========================================================================
    # STEP 2: Load current build status
    # ==========================================================================
    
    # Source the version tracking file
    # shellcheck disable=SC1090
    source "$version_file"
    
    local kernel_version="${KERNEL_VERSION:-unknown}"
    local build_status="${BUILD_STATUS:-unknown}"
    local sched_priority="${SCHED_PRIORITY:-0}"
    local build_date="${LAST_BUILD_DATE:-unknown}"
    
    # ==========================================================================
    # STEP 3: Load notification state (what we've already notified about)
    # ==========================================================================
    
    local last_notified_version=""
    local last_notified_status=""
    local last_notified_priority=""
    
    if [ -f "$notify_state_file" ]; then
        # shellcheck disable=SC1090
        source "$notify_state_file"
        last_notified_version="${NOTIFIED_VERSION:-}"
        last_notified_status="${NOTIFIED_STATUS:-}"
        last_notified_priority="${NOTIFIED_PRIORITY:-}"
    fi
    
    # ==========================================================================
    # STEP 4: Determine status and whether to notify
    # ==========================================================================
    
    local status=0
    local status_text="OK"
    local message=""
    local should_update_state=false
    
    # CRITICAL: Build failed completely
    if [ "$build_status" = "failed" ]; then
        status=2
        status_text="CRITICAL"
        message="Build FAILED for kernel $kernel_version (date: $build_date)"
        
        # Always notify on failures (don't check notification state)
        if [ "$last_notified_version" != "$kernel_version" ] || [ "$last_notified_status" != "failed" ]; then
            should_update_state=true
        fi
    
    # WARNING: Build succeeded but BORE patch didn't apply
    elif [ "$build_status" = "success" ] && [ "$sched_priority" = "1" ]; then
        status=1
        status_text="WARNING"
        message="Build succeeded but BORE patch NOT applied - using EEVDF fallback (kernel $kernel_version)"
        
        # Notify if this is a new version or state changed
        if [ "$last_notified_version" != "$kernel_version" ] || [ "$last_notified_priority" != "1" ]; then
            should_update_state=true
        fi
    
    # OK: Build succeeded with BORE
    elif [ "$build_status" = "success" ] && [ "$sched_priority" = "2" ]; then
        status=0
        status_text="OK"
        message="Build successful with BORE scheduler (kernel $kernel_version, date: $build_date)"
        
        # Notify only if this is a NEW version (don't spam on re-checks)
        if [ "$last_notified_version" != "$kernel_version" ]; then
            should_update_state=true
        fi
    
    # OK: Build succeeded (priority not set or other)
    elif [ "$build_status" = "success" ]; then
        status=0
        status_text="OK"
        message="Build successful (kernel $kernel_version, priority: $sched_priority, date: $build_date)"
        
        # Notify only on new version
        if [ "$last_notified_version" != "$kernel_version" ]; then
            should_update_state=true
        fi
    
    # UNKNOWN: Status unclear
    else
        status=3
        status_text="UNKNOWN"
        message="Unable to determine build status (kernel $kernel_version, status: $build_status)"
    fi
    
    # ==========================================================================
    # STEP 5: Update notification state if needed
    # ==========================================================================
    
    if [ "$should_update_state" = true ]; then
        cat > "$notify_state_file" << EOF
NOTIFIED_VERSION=$kernel_version
NOTIFIED_STATUS=$build_status
NOTIFIED_PRIORITY=$sched_priority
NOTIFIED_DATE=$(date -u +%Y-%m-%d)
EOF
    fi
    
    # ==========================================================================
    # STEP 6: Output CheckMK format
    # ==========================================================================
    
    # CheckMK local check format:
    # <status> <service_name> <metric>=<value>;<warn>;<crit>;<min>;<max> <text>
    
    local service_name="Harper_Build_${profile}"
    local metrics="sched_priority=$sched_priority;;;0;2"
    
    echo "$status $service_name $metrics $status_text: $message"
    
    return $status
}
