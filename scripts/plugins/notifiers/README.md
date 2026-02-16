# Harper Notifiers Plugins

Plugin-based notification and monitoring integration system.

## Overview

The notifiers system provides integrations with monitoring platforms, notification services, and other external systems. Plugins follow a standard interface for consistent integration.

## Plugin Architecture

**Plugin Runner:** `runner.sh`
- Main dispatcher that loads and executes notifier plugins
- Exports logging functions: `log_info()`, `log_ok()`, `log_warn()`, `log_error()`
- Routes to plugin functions: `{notifier_name}_check()`

**Available Plugins:**
- `harper_checkmk.sh` - CheckMK local check monitoring **specifically for Harper Deb13 builds**
  - Monitors: Build status, BORE scheduler priority (Harper-specific)
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
- Build succeeded with BORE scheduler (`SCHED_PRIORITY=2`)
- Build succeeded with other scheduler
- **Notification:** One-time when new version is built

**WARNING (1):**
- Build succeeded but BORE patch failed to apply (`SCHED_PRIORITY=1`)
- Falls back to EEVDF scheduler
- **Notification:** Persists until addressed (new build with BORE or manual clear)

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
    ├── NOTIFIED_PRIORITY=1
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
# For BORE warning: Trigger rebuild when BORE patch is available
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
    # Note: SCHED_PRIORITY is Harper-specific (1=EEVDF fallback, 2=BORE applied)
    cat << EOF
# HELP harper_build_status Build status (0=unknown, 1=success, 2=failed)
# TYPE harper_build_status gauge
harper_build_status{profile="$profile",version="$KERNEL_VERSION"} $([ "$BUILD_STATUS" = "success" ] && echo 1 || echo 2)

# HELP harper_scheduler_priority Scheduler priority (1=EEVDF, 2=BORE) - Harper Deb13 specific
# TYPE harper_scheduler_priority gauge
harper_scheduler_priority{profile="$profile",version="$KERNEL_VERSION"} $SCHED_PRIORITY
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
    
    # Note: SCHED_PRIORITY is Harper Deb13 specific
    # 1 = EEVDF fallback (BORE patch failed)
    # 2 = BORE successfully applied
    if [ "$BUILD_STATUS" = "failed" ]; then
        message="🚨 Harper Build FAILED for kernel $KERNEL_VERSION"
        color="danger"
    elif [ "$SCHED_PRIORITY" = "1" ]; then
        message="⚠️  Harper build succeeded but BORE patch not applied (kernel $KERNEL_VERSION) - using EEVDF fallback"
        color="warning"
    else
        message="✅ Harper build successful with BORE scheduler (kernel $KERNEL_VERSION)"
    fi
    
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"$message\",\"color\":\"$color\"}" \
        "$webhook_url"
}
```

## Cron Integration

Run checks periodically:

```bash
# Add to crontab
*/5 * * * * cd /path/to/Debian-Harper && source scripts/plugins/notifiers/runner.sh && notify harper_checkmk
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
