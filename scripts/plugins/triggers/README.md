# Harper Trigger Plugins

Plugin-based trigger system for automated kernel builds on upstream releases.

## Overview

The trigger system monitors upstream sources and automatically initiates builds when new kernel releases are detected. It uses a plugin architecture to support multiple upstream sources and execution backends.

## Plugin Architecture

**Plugin Runner:** `runner.sh`
- Main dispatcher that loads and executes trigger plugins
- Exports logging functions: `log_info()`, `log_ok()`, `log_warn()`, `log_error()`
- Routes to plugin functions via these exported functions:
  - `check_if_build_is_needed <plugin>` - Check if build needed
  - `build_successful <plugin>` - Callback when build succeeds
  - `build_failed <plugin> [error]` - Callback when build fails

**Plugin Interface (each plugin must implement):**

1. **`{plugin}_trigger()`** - Detection function
   - Checks if new version available
   - Exports: `DETECTED_KERNEL_VERSION`, `DETECTED_BUILD_REASON`
   - Returns: 0=build needed, 1=no action

2. **`{plugin}_build_successful()`** - Success callback
   - Updates version tracking file
   - Called after successful build

3. **`{plugin}_build_failed()`** - Failure callback  
   - Handles build failures
   - Optional: update tracking to skip failed versions

**Available Plugins:**
- `harper_deb13_kernel.sh` - Debian Trixie Backports kernel releases
  - Monitors: Debian Salsa API
  - Tracks: Version in `version_tracking/harper_deb13_latest_kernel.txt`
  - Exports: `DETECTED_KERNEL_VERSION` for use in callbacks

## Usage

### Load the Runner

```bash
source ./scripts/plugins/triggers/runner.sh
```

### Check and Execute Build

```bash
# Check if new kernel version available
check_if_build_is_needed harper_deb13_kernel

if [[$? -eq 0 ]]; then
    echo "Build needed for kernel version: $DETECTED_KERNEL_VERSION"
    
    # Execute your build here
    if ./start_build.sh --params-file params/harper_deb13.params; then
        # Build succeeded - update tracking
        build_successful harper_deb13_kernel
    else
        # Build failed - handle error
        build_failed harper_deb13_kernel "build_exit_$?"
    fi
else
    echo "No build needed - already up to date"
fi
```

### Force Build

```bash
# Force build regardless of version comparison
check_if_build_is_needed harper_deb13_kernel --force
```

### Create a New Plugin

1. **Create plugin file:** `scripts/plugins/triggers/{name}.sh`

2. **Implement the three required functions:**

```bash
#!/bin/bash
# Harper Foundry: Custom Trigger Plugin

VERSION_TRACKING_FILE="$REPO_ROOT/version_tracking/my_custom_latest.txt"

# REQUIRED: Detection function
my_custom_trigger() {
    local force_build="${1:-}"
    
    log_info "=== My Custom Trigger ==="
    
    # 1. Query upstream source for latest version
    local latest_version="1.2.3"  # Your detection logic here
    
    # 2. Load last built version from tracking file
    source "$VERSION_TRACKING_FILE"
    local last_version="${VERSION:-unknown}"
    
    # 3. Compare and decide
    if [[ "$latest_version" != "$last_version" ]]; then
        # Export detected version for callbacks
        export DETECTED_VERSION="$latest_version"
        export DETECTED_BUILD_REASON="new_version"
        
        log_warn "Build needed: $latest_version"
        return 0  # Build needed
    else
        log_ok "Already up to date: $last_version"
        return 1  # No action needed
    fi
}

# REQUIRED: Success callback
my_custom_build_successful() {
    log_info "=== Build Success Callback ==="
    
    # Update version tracking file
    cat > "$VERSION_TRACKING_FILE" << EOF
VERSION=$DETECTED_VERSION
LAST_BUILD_DATE=$(date -u +%Y-%m-%d)
BUILD_STATUS=success
EOF
    
    log_ok "Version tracking updated"
    return 0
}

# REQUIRED: Failure callback
my_custom_build_failed() {
    local error_info="${1:-unknown}"
    
    log_error "Build failed: $error_info"
    
    # Optionally update tracking to skip this version
    # (Comment out to retry failed versions)
    # cat > "$VERSION_TRACKING_FILE" << EOF
    # VERSION=$DETECTED_VERSION
    # BUILD_STATUS=failed
    # EOF
    
    return 0
}
```

3. **Test your plugin:**

```bash
source ./scripts/plugins/triggers/runner.sh
check_if_build_is_needed my_custom
```

3. **Make executable:**
```bash
chmod +x scripts/plugins/triggers/my_trigger.sh
```

4. **Test:**
```bash
trigger_build my_trigger
trigger_build my_trigger --force
```

## Plugin Function Signature

```bash
{trigger_name}_trigger() {
    # Parameters:
    # $1 = First option (commonly --force)
    # $@ = All options
    
    # Returns:
    # 0 = Success (build triggered or no action needed)
    # 1 = Error occurred
}
```

## Logging Functions

Available in all plugins (exported from `runner.sh`):

```bash
log_info "Information message"      # Blue [INFO]
log_ok "Success message"            # Green [OK]
log_warn "Warning message"          # Yellow [WARN]
log_error "Error message"           # Red [ERROR]
```

## Environment Variables

Available to plugins:

```bash
PLUGINS_DIR      # Directory containing this file
REPO_ROOT        # Root directory of Harper repository
```

## Integration with GitHub Actions

The `.github/workflows/monitor-deb13-kernel.yml` workflow calls:

```bash
source ./scripts/plugins/triggers/runner.sh
trigger_build harper_deb13_kernel
```

To add a new trigger to the workflow, update the workflow file to call:

```bash
trigger_build your_new_trigger_name
```

## Local Cron Job Setup

For running triggers locally without GitHub Actions, use the provided cron example:

### Quick Setup

1. **Copy the example:**
   ```bash
   cp scripts/plugins/triggers/cron_example.sh scripts/plugins/triggers/my_cron.sh
   ```

2. **Edit paths in the file:**
   ```bash
   # Update REPO_ROOT to your Harper installation path
   export REPO_ROOT="/path/to/your/Debian-Harper"
   ```

3. **Customize build execution** (uncomment and modify one of the placeholder options):
   - Option A: Direct Docker build
   - Option B: Custom build script
   - Option C: Queue for batch processing

4. **Add to crontab:**
   ```bash
   crontab -e
   # Add line (every 6 hours):
   0 */6 * * * /path/to/Debian-Harper/scripts/plugins/triggers/my_cron.sh
   ```

### Important Notes

**Environment Variables:**
- Cron runs with minimal environment - script sets everything explicitly
- `PATH` is set to include common binary locations
- `REPO_ROOT` must be set to absolute path

**Logging:**
- Default log location: `logs/trigger_cron.log`
- Output is both written to file and visible in cron emails
- Change `LOGFILE` variable to customize location

**Cron Schedule Examples:**
```bash
0 */6 * * *   # Every 6 hours
0 */12 * * *  # Every 12 hours
0 0 * * *     # Daily at midnight
0 3 * * 1     # Weekly on Monday at 3 AM
0 0 1 * *     # Monthly on the 1st at midnight
```

## Examples

### Monitor Fedora Kernel Releases

Create `scripts/plugins/triggers/fedora_kernel.sh`:

```bash
#!/bin/bash

fedora_kernel_trigger() {
    log_info "=== Fedora Kernel Monitor ==="
    
    # Query Fedora APIs, etc.
    local latest_version=$(curl -s https://koji.fedoraproject.org/koji/api/builds | ...)
    
    # Compare and trigger build
    if [[ "$latest_version" != "$current_version" ]]; then
        log_warn "New Fedora kernel: $latest_version"
        # Trigger build here
    fi
    
    log_ok "Fedora kernel check complete"
}
```

### Chain Multiple Triggers

```bash
#!/bin/bash
source ./scripts/plugins/triggers/runner.sh

# Monitor multiple sources in sequence
trigger_build harper_deb13_kernel && \
trigger_build fedora_kernel # if it exists
```

## Troubleshooting

**Plugin not found:**
```
[ERROR]  Trigger plugin not found: my_trigger
[ERROR]  Expected: ./scripts/plugins/triggers/my_trigger.sh
```
→ Verify the plugin file exists and is in the correct directory: `scripts/plugins/triggers/{name}.sh`

**Function not defined:**
```
[ERROR]  Plugin my_trigger does not define my_trigger_trigger function
```
→ Verify function is named correctly: `{plugin_name}_trigger()`

**Permission denied:**
```
bash: ./scripts/plugins/triggers/my_plugin.sh: Permission denied
```
→ Make the plugin executable: `chmod +x scripts/plugins/triggers/my_plugin.sh`

## Related Documentation

- [Trigger Jobs Guide](../../docs/TRIGGER_JOBS.md) - Comprehensive setup and customization
- [Kernel Plugins Guide](../kernelsources/README.md) - Similar plugin architecture for kernel sources
- [GitHub Actions Monitoring Workflow](.github/workflows/monitor-deb13-kernel.yml)
