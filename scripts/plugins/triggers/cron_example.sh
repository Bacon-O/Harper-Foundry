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
#      Example: 0 */6 * * * /path/to/harper/scripts/plugins/triggers/cron_example.sh
#
# IMPORTANT: Cron jobs need explicit environment variables and full paths!
# ==============================================================================

set -euo pipefail

# ==============================================================================
# ENVIRONMENT SETUP
# ==============================================================================
# Cron runs with minimal environment - set everything explicitly

# Repository root (CHANGE THIS to your Harper installation path)
export REPO_ROOT="/path/to/repo/root"

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

# Source the runner (loads trigger_build function)
source "$REPO_ROOT/scripts/plugins/triggers/runner.sh"

# ==============================================================================
# STEP 2: Run Trigger Check
# ==============================================================================

log_to_file "Checking for new kernel releases..."

# Run the trigger plugin
if trigger_build harper_deb13_kernel 2>&1 | tee -a "$LOGFILE"; then
    TRIGGER_EXIT_CODE=${PIPESTATUS[0]}
else
    TRIGGER_EXIT_CODE=$?
fi

log_to_file "Trigger check completed with exit code: $TRIGGER_EXIT_CODE"

# ==============================================================================
# STEP 3: Execute Build if Triggered (PLACEHOLDER)
# ==============================================================================
# This is where you would actually execute the build if a new version was detected
# The trigger plugin above only CHECKS for new versions - it doesn't build yet

# OPTION A: Build directly with Docker
# if [ $TRIGGER_EXIT_CODE -eq 0 ]; then
#     log_to_file "Executing build with tinyconfig for testing..."
#     
#     # Set build environment variables
#     export HOST_OUTPUT_DIR="$REPO_ROOT/output"
#     
#     # Run the build
#     if "$REPO_ROOT/start_build.sh" --params-file "$REPO_ROOT/params/tinyconfig.params" 2>&1 | tee -a "$LOGFILE"; then
#         log_to_file "Build completed successfully"
#         
#         # Update version tracking file with build results
#         # (You'd need to extract SCHED_PRIORITY from build logs)
#         # cat > "$REPO_ROOT/version_tracking/harper_deb13_latest_kernel.txt" << EOF
#         # KERNEL_VERSION=<detected_version>
#         # LAST_BUILD_DATE=$(date -u +%Y-%m-%d)
#         # BUILD_STATUS=success
#         # SCHED_PRIORITY=<extracted_from_build>
#         # EOF
#     else
#         log_to_file "Build failed"
#     fi
# fi

# OPTION B: Use a dedicated build execution script
# if [ $TRIGGER_EXIT_CODE -eq 0 ]; then
#     "$REPO_ROOT/scripts/execute_triggered_build.sh" 2>&1 | tee -a "$LOGFILE"
# fi

# OPTION C: Queue the build for later execution
# if [ $TRIGGER_EXIT_CODE -eq 0 ]; then
#     echo "build:harper_deb13:$(date +%s)" >> "$REPO_ROOT/build_queue.txt"
#     log_to_file "Build queued for processing"
# fi

log_to_file "=== Trigger Cron Job Complete ==="

# Return successful exit code (cron will email on non-zero exit)
exit 0
