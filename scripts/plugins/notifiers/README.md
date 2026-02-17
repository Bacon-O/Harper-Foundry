# Harper Notifiers Plugins

Plugin-based notification and monitoring integration system.

## Directory Structure

```
notifiers/
├── harper_checkmk.sh           # CheckMK monitoring plugin
├── harper_checkmk_wrapper.sh   # CheckMK agent wrapper
├── runner.sh                   # Plugin router/dispatcher
└── README.md                   # This file

scripts.d/plugins/notifiers/    # Your custom notifiers (gitignored)
└── (your custom notifiers here)
```

## Overview

The notifiers system provides integrations with monitoring platforms, notification services, and other external systems. Plugins follow a standard interface for consistent integration.

## Plugin Architecture

**Plugin Runner:** `runner.sh`
- Main dispatcher that loads and executes notifier plugins
- Exports logging functions: `log_info()`, `log_ok()`, `log_warn()`, `log_error()`
- Routes to plugin functions: `{notifier_name}_check()`

**Available Plugins:**
- `harper_checkmk.sh` - CheckMK local check monitoring **specifically for Harper Deb13 builds**
  - Monitors: Build status and kernel version updates (Harper-specific)
  - Notifications: One-time on new builds, persistent warnings/criticals
  - Exit codes: 0=OK, 1=WARNING, 2=CRITICAL, 3=UNKNOWN

## Usage

### Load the Runner

```bash
source ./scripts/plugins/notifiers/runner.sh
```

### CheckMK Integration

**Run check manually:**
```bash
notify harper_checkmk
notify harper_checkmk --profile harper_deb13
```

**Add to CheckMK agent:**
```bash
# Create symlink in CheckMK local checks directory
sudo ln -s /path/to/Debian-Harper/scripts/plugins/notifiers/harper_checkmk_wrapper.sh \
  /usr/lib/check_mk_agent/local/harper_builds

# Or create wrapper script (customize REPO_ROOT path):
cat > /usr/lib/check_mk_agent/local/harper_builds << 'EOF'
#!/bin/bash
REPO_ROOT="/path/to/Debian-Harper"  # CHANGE THIS to your repo path
source "$REPO_ROOT/scripts/plugins/notifiers/runner.sh"
notify harper_checkmk --profile harper_deb13
EOF
chmod +x /usr/lib/check_mk_agent/local/harper_builds
```

## CheckMK Notification Logic (Harper Deb13)

The CheckMK plugin implements smart notification logic to avoid spam:

### Status Levels

**OK (0):**
- Build succeeded
- **Notification:** One-time when new version is built

**CRITICAL (2):**
- Build failed completely (`BUILD_STATUS=failed`)
- **Notification:** Persists until fixed

**UNKNOWN (3):**
- Version tracking file missing or status unclear

### Notification State Tracking

The plugin tracks notification state in `version_tracking/.notification_state/`:

```
version_tracking/.notification_state/
└── harper_deb13_notified.txt
    ├── NOTIFIED_VERSION=6.11.8
    ├── NOTIFIED_STATUS=success
    └── NOTIFIED_DATE=2026-02-15
```

**State Update Logic:**
- **New version** → Always update state and notify
- **Status changed** → Update state and notify
- **Same version + same status** → No notification (already notified)

### Clearing Notifications

To manually clear persistent warnings:

```bash
# Remove notification state file
rm version_tracking/.notification_state/harper_deb13_notified.txt

# Next check will re-evaluate and notify based on current status
```

Or rebuild kernel to address the issue:

```bash
# Trigger rebuild when new kernel version is available
source ./scripts/plugins/triggers/runner.sh
trigger_build harper_deb13_kernel --force

# For build failure: Fix the issue and rebuild
```

## Creating a New Plugin

1. **Create plugin file:** `scripts/plugins/notifiers/{notifier_name}.sh`

2. **Implement function:** `{notifier_name}_check()`

```bash
#!/bin/bash
# Harper Foundry: Custom Notifier Plugin

email_notifier_check() {
    local profile="${1:-harper_deb13}"
    
    # Your implementation:
    # 1. Read version tracking file
    # 2. Determine status
    # 3. Send notification/update monitoring system
    # 4. Return appropriate exit code
    
    local version_file="$REPO_ROOT/version_tracking/${profile}_latest_kernel.txt"
    source "$version_file"
    
    # Example: Send email
    echo "Build status for $profile: $BUILD_STATUS (kernel $KERNEL_VERSION)" | \
      mail -s "Harper Build Notification" admin@example.com
    
    return 0  # or 1, 2, 3 for WARNING, CRITICAL, UNKNOWN
}
```

3. **Make executable:**
```bash
chmod +x scripts/plugins/notifiers/email_notifier.sh
```

4. **Test:**
```bash
source ./scripts/plugins/notifiers/runner.sh
notify email_notifier --profile harper_deb13
```

## Environment Variables

Available to plugins:

```bash
PLUGINS_DIR      # Directory containing this file
REPO_ROOT        # Root directory of Harper repository
```

## Integration Examples

### Prometheus Node Exporter

Create `scripts/plugins/notifiers/prometheus.sh`:

```bash
#!/bin/bash

prometheus_check() {
    local profile="${1:-harper_deb13}"
    local version_file="$REPO_ROOT/version_tracking/${profile}_latest_kernel.txt"
    
    source "$version_file"
    
    # Output Prometheus text format
    # Note: Build outcomes tracked via NOTIFIED_STATUS
    cat << EOF
# HELP harper_build_status Build status (0=failed, 1=success)
# TYPE harper_build_status gauge
harper_build_status{profile="$profile",version="$KERNEL_VERSION"} $([ "$BUILD_STATUS" = "success" ] && echo 1 || echo 0)
EOF
    
    return 0
}
```

### Slack Notification

Create `scripts/plugins/notifiers/slack.sh`:

```bash
#!/bin/bash

slack_check() {
    local webhook_url="$SLACK_WEBHOOK_URL"
    local profile="${1:-harper_deb13}"
    
    source "$REPO_ROOT/version_tracking/${profile}_latest_kernel.txt"
    
    local message=""
    local color="good"
    
    # Build status tracking
    # 1 = Success
    # 0 = Failed
    if [ "$BUILD_STATUS" = "failed" ]; then
        message="🚨 Harper Build FAILED for kernel $KERNEL_VERSION"
        color="danger"
    else
        message="✅ Harper build successful (kernel $KERNEL_VERSION)"
    fi
    
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"$message\",\"color\":\"$color\"}" \
        "$webhook_url"
}
```

## Creating Custom Notifiers

### User Custom Notifiers (Recommended)

To add a custom notifier plugin without modifying project files:

1. Create a plugin in `scripts/scripts.d/plugins/notifiers/`:
   ```bash
   cat > scripts/plugins/notifiers/my_service.sh << 'EOF'
   #!/bin/bash
   
   my_service_check() {
       local profile="${1:-harper_deb13}"
       
       # Load version tracking
       source "$REPO_ROOT/version_tracking/${profile}_latest_kernel.txt"
       
       # Send notification to your service
       curl -X POST https://my-service.com/builds \
           -d "kernel=$KERNEL_VERSION&status=$BUILD_STATUS"
       
       # Return CheckMK exit code: 0=OK, 1=WARNING, 2=CRITICAL, 3=UNKNOWN
       return 0
   }
   EOF
   chmod +x scripts/scripts.d/plugins/notifiers/my_service.sh
   ```

2. Use in your build workflow:
   ```bash
   source scripts/plugins/notifiers/runner.sh
   notify my_service --profile harper_deb13
   ```

**Benefits**:
- ✅ Keeps custom logic separate from project code
- ✅ Easy to share different notification integrations
- ✅ Safe from git conflicts during updates

### Plugin Interface

Custom notifiers must implement:

**Function signature:**
```bash
{plugin_name}_check() {
    # $1 = profile name (optional, defaults to "harper_deb13")
    local profile="${1:-harper_deb13}"
    
    # Your notification logic here
    # ...
    
    # Return CheckMK exit code
    return 0  # 0=OK, 1=WARNING, 2=CRITICAL, 3=UNKNOWN
}
```

**Available functions:**
- `log_info()` - Informational message
- `log_ok()` - Success message
- `log_warn()` - Warning message
- `log_error()` - Error message

**Available variables:**
- `$REPO_ROOT` - Repository root directory
- `$PLUGINS_DIR` - Notifiers plugin directory

## Cron Integration

Run checks periodically:

```bash
# Add to crontab
*/5 * * * * cd /path/to/repo && source scripts/plugins/notifiers/runner.sh && notify harper_checkmk
```

Or use dedicated wrapper scripts for each notifier.

## Troubleshooting

**Repeated notifications for same version:**
```
Problem: Getting notified repeatedly for the same build
Solution: Check notification state file exists and is being updated
  ls -la version_tracking/.notification_state/
```

**CheckMK not detecting issues:**
```
Problem: CheckMK shows OK when build actually failed
Solution: Verify version tracking file has correct BUILD_STATUS
  cat version_tracking/harper_deb13_latest_kernel.txt
```

**Notification state corruption:**
```
Problem: State file has wrong data
Solution: Remove and let it regenerate
  rm version_tracking/.notification_state/*.txt
```

## Related Documentation

- [Trigger Jobs Guide](../../docs/TRIGGER_JOBS.md) - Automated build triggers
- [Version Tracking](../../../version_tracking/README.md) - Version tracking format
- [CheckMK Local Checks](https://docs.checkmk.com/latest/en/localchecks.html) - Official CheckMK docs
