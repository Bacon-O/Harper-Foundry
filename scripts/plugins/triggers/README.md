# Harper Trigger Plugins

Plugin-based trigger system for automated kernel builds on upstream releases.

## Overview

The trigger system monitors upstream sources and automatically initiates builds when new kernel releases are detected. It uses a plugin architecture to support multiple upstream sources and execution backends.

## Plugin Architecture

**Plugin Runner:** `runner.sh`
- Main dispatcher that loads and executes trigger plugins
- Exports logging functions: `log_info()`, `log_ok()`, `log_warn()`, `log_error()`
- Routes to plugin functions: `{trigger_name}_trigger()`

**Available Plugins:**
- `alloy_deb13_kernel.sh` - Debian Trixie Backports kernel releases
  - Monitors: Debian Salsa API
  - Tracks: Version in `version_tracking/alloy_deb13_latest_kernel.txt`
  - Executes: Build trigger (placeholder)

## Usage

### Load the Runner

```bash
source ./scripts/plugins/triggers/runner.sh
```

### Trigger Manually

```bash
# Check for new kernel versions
trigger_build alloy_deb13_kernel

# Force build regardless of version
trigger_build alloy_deb13_kernel --force
```

### Create a New Plugin

1. **Create plugin file:** `scripts/plugins/triggers/{name}.sh`

2. **Implement function:** `{name}_trigger()`

```bash
#!/bin/bash
# Harper Foundry: Custom Trigger Plugin

my_trigger_trigger() {
    local force_build="${1:-}"
    
    log_info "=== My Custom Trigger ==="
    
    # Your implementation:
    # 1. Check upstream source
    # 2. Compare against last built version
    # 3. Trigger build if needed
    
    log_ok "Trigger executed"
}
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
trigger_build alloy_deb13_kernel
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
    if [ "$latest_version" != "$current_version" ]; then
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
trigger_build alloy_deb13_kernel && \
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
