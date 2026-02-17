#!/bin/bash

# ==============================================================================
# Harper Foundry: Cron Job Example for Trigger System
# ==============================================================================
# Example cron job for running kernel build triggers locally without GitHub Actions
#
# USAGE:
#   1. Copy this file and customize for your environment
#   2. Make executable: chmod +x cron_example.sh
#   3. Add to crontab: crontab -e
#      Example: 0 */6 * * * /path/to/repo/scripts/plugins/triggers/cron_example.sh
#
# IMPORTANT: Cron jobs need explicit environment variables and full paths!
# ==============================================================================

set -euo pipefail

# ==============================================================================
# ENVIRONMENT SETUP
# ==============================================================================
# Cron runs with minimal environment - set everything explicitly

# Repository root - auto-detect from script location
# Script is in: scripts/plugins/triggers/cron_example.sh
# Repo root is: ../../../ from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
export REPO_ROOT

# Change to repo directory
cd "$REPO_ROOT" || exit 1

# Add common binary paths (cron has minimal PATH)
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# Logging (optional - redirect output to file)
LOGFILE="$REPO_ROOT/logs/trigger_cron.log"
mkdir -p "$(dirname "$LOGFILE")"

# Locking (prevent overlapping runs)
LOCK_DIR="$REPO_ROOT/var/lock"
LOCK_FILE="$LOCK_DIR/harper_trigger_cron.lock"
mkdir -p "$LOCK_DIR"

if command -v flock >/dev/null 2>&1; then
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        echo "[$(date -u +%Y-%m-%d\ %H:%M:%S\ UTC)] Another cron run is active. Exiting." | tee -a "$LOGFILE"
        exit 0
    fi
else
    echo "[$(date -u +%Y-%m-%d\ %H:%M:%S\ UTC)] WARNING: flock not found; lock disabled." | tee -a "$LOGFILE"
fi

# Logging helper
log_to_file() {
    echo "[$(date -u +%Y-%m-%d\ %H:%M:%S\ UTC)] $1" | tee -a "$LOGFILE"
}

log_to_file "=== Starting Harper Trigger Cron Job ==="

# ==============================================================================
# STEP 1: Source the Trigger Plugin Runner
# ==============================================================================

if [ ! -f "$REPO_ROOT/scripts/plugins/triggers/runner.sh" ]; then
    log_to_file "ERROR: Trigger runner not found at $REPO_ROOT/scripts/plugins/triggers/runner.sh"
    exit 1
fi

# Source the runner (loads check_if_build_is_needed function)
source "$REPO_ROOT/scripts/plugins/triggers/runner.sh"

# ==============================================================================
# STEP 2: Check If Build Is Needed
# ==============================================================================

log_to_file "Checking if new kernel versions are available..."

# Check if a new version is available that needs building
# IMPORTANT: Don't use pipes or $()! Those create subshells and lose exported variables
# Use process substitution with tee to log output while preserving exports
check_if_build_is_needed harper_deb13_kernel > >(tee -a "$LOGFILE") 2>&1
BUILD_NEEDED=$?

log_to_file "Check completed with exit code: $BUILD_NEEDED (0=build needed, non-zero=no action)"

# ==============================================================================
# STEP 3: Execute Build (if Check Indicated Build Is Needed)
# ==============================================================================
# The check function ONLY detects - it does NOT execute builds
# If BUILD_NEEDED=0, we execute the build here and use plugin CALLBACKS for tracking
#
# Callback Flow:
#   1. check_if_build_is_needed <plugin>  → plugin exports DETECTED_KERNEL_VERSION
#   2. Run your build (start_build.sh, script, queue, etc.)
#   3. build_successful <plugin>          → runner.sh routes to plugin's success callback
#      OR
#      build_failed <plugin> "reason"     → runner.sh routes to plugin's failure callback
#
# The plugin callbacks handle ALL version tracking logic - you just call them!
# ==============================================================================

# OPTION A: Build directly with Docker
if [ $BUILD_NEEDED -eq 0 ]; then
    log_to_file "Build needed for kernel version: ${DETECTED_KERNEL_VERSION}"
    log_to_file "Executing build with tinyconfig for testing..."
    
    # Set build environment variables
    export HOST_OUTPUT_DIR="$REPO_ROOT/output"
    
    # Change to repo root so relative paths work correctly
    cd "$REPO_ROOT" || exit 1
    
    # Run the build using RELATIVE path only (no $REPO_ROOT prefix)
    if ./start_build.sh --params-file params/tinyconfig.params 2>&1 | tee -a "$LOGFILE"; then
        log_to_file "Build completed successfully"
        
        # Callback to plugin: updates version tracking file automatically
        # Flow: build_successful → runner.sh → harper_deb13_kernel_build_successful()
        build_successful harper_deb13_kernel 2>&1 | tee -a "$LOGFILE"
    else
        BUILD_EXIT_CODE=$?
        log_to_file "Build failed with exit code: $BUILD_EXIT_CODE"
        
        # Callback to plugin: handles failure (optionally skip this version)
        # Flow: build_failed → runner.sh → harper_deb13_kernel_build_failed()
        build_failed harper_deb13_kernel "exit_code_$BUILD_EXIT_CODE" 2>&1 | tee -a "$LOGFILE"
    fi
fi

# OPTION B: Use a dedicated build execution script
# if [ $BUILD_NEEDED -eq 0 ]; then
#     log_to_file "Build needed for kernel version: ${DETECTED_KERNEL_VERSION}"
#     
#     if "$REPO_ROOT/scripts/execute_triggered_build.sh" 2>&1 | tee -a "$LOGFILE"; then
#         # Plugin callback handles all version tracking
#         build_successful harper_deb13_kernel 2>&1 | tee -a "$LOGFILE"
#     else
#         # Plugin callback handles failure
#         build_failed harper_deb13_kernel "script_failed" 2>&1 | tee -a "$LOGFILE"
#     fi
# fi

# OPTION C: Queue the build for later execution
# if [ $BUILD_NEEDED -eq 0 ]; then
#     # Queue includes the detected version (exported by check function)
#     echo "build:harper_deb13_kernel:$(date +%s):${DETECTED_KERNEL_VERSION}" >> "$REPO_ROOT/build_queue.txt"
#     log_to_file "Build queued for kernel version ${DETECTED_KERNEL_VERSION}"
#     
#     # Note: When processing queue, call build_successful/build_failed callbacks
#     # to update version tracking after build completes
# fi

log_to_file "=== Trigger Cron Job Complete ==="

# Return successful exit code (cron will email on non-zero exit)
exit 0
