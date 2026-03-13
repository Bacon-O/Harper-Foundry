# Trigger Jobs - Automated Kernel Build Pipeline

This document describes how to set up and customize automated trigger jobs for building new kernel versions when releases become available.

**Example Implementation:** This guide uses the **Harper Deb13** build profile as the reference example, demonstrating automated builds triggered by Debian Trixie Backports kernel releases.

## Overview

The trigger job system uses a **plugin-based architecture** to monitor upstream kernel releases (e.g., Debian Trixie Backports for Deb13) and automatically build new versions when detected. This enables:
- **Zero-downtime updates**: New kernels built immediately upon release
- **Version tracking**: Maintains history of which versions have been successfully built
- **Flexible execution**: Background builds, scheduled jobs, or manual triggers
- **Extensible design**: Add new trigger types (different upstreams) without modifying core code

## Architecture

**Diagram: Harper Deb13 Automated Build Pipeline with Callbacks**

```
┌─────────────────────────────────────────────────────────────┐
│  Upstream Scheduler (Cron or GitHub Actions)                │
│  - Local: cron_example.sh (runs with provided schedule)    │
│  - CI: .github/workflows/monitor-deb13-kernel.yml (6h)    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Executes: check_if_build_is_needed()
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: Trigger Plugin Runner (Dispatcher)                │
│  (scripts/plugins/triggers/runner.sh)                       │
│                                                             │
│  - Loads appropriate trigger plugin                         │
│  - Exports: DETECTED_KERNEL_VERSION, DETECTED_BUILD_REASON │
│  - Returns: 0=build needed, 1=no action                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Calls: harper_deb13_kernel_trigger()
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: Trigger Detection Plugin                           │
│  (scripts/plugins/triggers/harper_deb13_kernel.sh)         │
│                                                             │
│  1. Query Debian backports source index for latest version  │
│  2. Load last successfully built version                    │
│  3. Compare versions                                        │
│  4. Export DETECTED_KERNEL_VERSION if new                   │
│  5. Return: 0 if build needed, 1 if not                    │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
   ┌─────────┐          ┌─────────────────┐
   │Return 1 │          │Return 0 (Build  │
   │No Action │         │Needed)          │
   │Needed    │          │                 │
   └─────────┘          └────────┬────────┘
                                  │
                 ┌────────────────┴─────────────────┐
                 │                                  │
                 ▼                                  ▼
       ┌──────────────────┐          ┌──────────────────────┐
       │STEP 3: Execute   │          │STEP 4: Success       │
       │Build (Optional)  │          │Callback              │
       │                  │          │                      │
       │./start_build.sh  │──────────▶│build_successful()    │
       │--params-file ... │          │(Updates tracking)    │
       └──────────────────┘          └──────────────────────┘
               │                              │
               │ (if fails)                   │
               └──────────────┬───────────────┘
                              │
                              ▼
                   ┌──────────────────────┐
                   │Failure Callback      │
                   │                      │
                   │build_failed()        │
                   │(Log error, optional  │
                   │ version skipping)    │
                   └──────────────────────┘
```

## Setup

### 1. Install Prerequisites

```bash
# Required for Linux
sudo apt-get install -y curl jq

# Optional: GitHub CLI for workflow triggers
sudo apt-get install -y gh
```

### 2. Version Tracking Directory

The `version_tracking/` directory maintains state for each build profile:

**Example: Deb13**
```
version_tracking/
├── README.md                        # This directory's documentation
└── harper_deb13_latest_kernel.txt    # Last successful kernel version (Deb13)
    ├── KERNEL_VERSION=6.11.8
    ├── LAST_BUILD_DATE=2026-02-15
    └── BUILD_STATUS=success
```

### 3. Trigger Plugin System

Trigger plugins live in `scripts/plugins/triggers/`:

**Example: Deb13 plugin**
```
scripts/plugins/triggers/
├── runner.sh                 # Main dispatcher (routes to plugins)
├── harper_deb13_kernel.sh     # Debian Trixie kernel monitor plugin (EXAMPLE)
└── README.md                # Plugin system documentation
```

### 4. GitHub Actions Workflow

The workflow `.github/workflows/monitor-deb13-kernel.yml` (configured for Deb13) runs on:
- **Schedule**: Every 6 hours (configurable)
- **Manual Dispatch**: Anytime via GitHub UI or `gh` CLI

## Usage

### Automatic Monitoring (GitHub Actions)

The workflow runs automatically on the schedule. View results:

```bash
# View workflow runs
gh run list --workflow monitor-deb13-kernel.yml

# View latest run
gh run view --workflow monitor-deb13-kernel.yml -v
```

### Manual Trigger

**Via GitHub CLI:**
```bash
gh workflow run monitor-deb13-kernel.yml
```

**Via GitHub UI:**
1. Go to `.github/workflows/monitor-deb13-kernel.yml`
2. Click "Run workflow" button
3. Optionally set `force_build=true` to skip version comparison

**Locally (via trigger plugin system):**
```bash
# Load the trigger plugin runner and execute (harper_deb13 example)
source ./scripts/plugins/triggers/runner.sh

# Check if build is needed (STEP 1: Detection)
check_if_build_is_needed harper_deb13_kernel
BUILD_NEEDED=$?

if [[ $BUILD_NEEDED -eq 0 ]]; then
    echo "Build needed for kernel version: ${DETECTED_KERNEL_VERSION}"
    
    # STEP 2: Execute build (optional - you implement this)
    if ./start_build.sh --params-file params/tinyconfig.params; then
        echo "Build successful"
        
        # STEP 3: Success callback (plugin updates tracking automatically)
        build_successful harper_deb13_kernel
    else
        echo "Build failed"
        
        # Failure callback (plugin handles failure logic)
        build_failed harper_deb13_kernel "build_exit_${?}"
    fi
else
    echo "No action needed - version already built"
fi

# Force build regardless of version:
check_if_build_is_needed harper_deb13_kernel --force
```

## Plugin Interface: Three-Function Pattern

Each trigger plugin implements three functions that form the complete trigger lifecycle:

### 1. `<plugin>_trigger()` - Detection Phase

**Purpose:** Check if build is needed

**Returns:**
- `0` - Build IS needed (new version detected)
- `1` - Build NOT needed (version already built)

**Exports:**
- `DETECTED_KERNEL_VERSION` - Version string for build
- `DETECTED_BUILD_REASON` - Reason ("new_version" or "forced")

**Example:**
```bash
harper_deb13_kernel_trigger() {
    # Query API, compare versions
    if [[ new_version_found ]]; then
        export DETECTED_KERNEL_VERSION="6.12.5"
        export DETECTED_BUILD_REASON="new_version"
        return 0  # Build needed
    else
        return 1  # No action needed
    fi
}
```

### 2. `<plugin>_build_successful()` - Success Callback

**Purpose:** Handle successful build completion

**Responsibility:**
- Update version tracking file
- Record successful build metadata
- Prepare for next trigger check

**Example:**
```bash
harper_deb13_kernel_build_successful() {
    log_ok "Build succeeded for ${DETECTED_KERNEL_VERSION}"
    
    # Update tracking file
    cat > "$VERSION_TRACKING_FILE" << EOF
KERNEL_VERSION=$DETECTED_KERNEL_VERSION
LAST_BUILD_DATE=$(date -u +%Y-%m-%d)
BUILD_STATUS=success
EOF
    
    return 0
}
```

### 3. `<plugin>_build_failed()` - Failure Callback

**Purpose:** Handle build failures

**Responsibility:**
- Log failure details
- Optionally skip this version (prevent retry loops)
- Prepare for next attempt

**Example:**
```bash
harper_deb13_kernel_build_failed() {
    local error_info="${1:-unknown}"
    
    log_error "Build failed for ${DETECTED_KERNEL_VERSION}: $error_info"
    
    # Optionally update tracking to skip failed version:
    # cat > "$VERSION_TRACKING_FILE" << EOF
    # KERNEL_VERSION=$DETECTED_KERNEL_VERSION
    # BUILD_STATUS=failed
    # BUILD_ERROR=$error_info
    # EOF
    
    return 0
}
```

## Build Execution: Implementation Options

The **detection** (Step 1-2) is handled by the plugin. The **build execution** (Step 3-4) is your responsibility. Choose the approach best for your infrastructure:

### Option 1: Local Docker Build (Default)
Execute immediately on the trigger machine:
```bash
if [[ $BUILD_NEEDED -eq 0 ]]; then
    ./start_build.sh --params-file params/tinyconfig.params
    if [[ $? -eq 0 ]]; then
        build_successful harper_deb13_kernel
    else
        build_failed harper_deb13_kernel "build_exit_${?}"
    fi
fi
```

See `scripts/plugins/triggers/cron_example.sh` for full example.

### Option 2: GitHub Actions Workflow
Use the existing workflow for distributed execution:
```bash
# In .github/workflows/monitor-deb13-kernel.yml
check_if_build_is_needed harper_deb13_kernel
if [[ $? -eq 0 ]]; then
    ./start_build.sh --params-file params/tinyconfig.params
    build_successful harper_deb13_kernel  # Plugin handles tracking
fi
```

See `.github/workflows/monitor-deb13-kernel.yml` for current implementation.

### Option 3: Remote SSH Build
Delegate to a build server:
```bash
if [[ $BUILD_NEEDED -eq 0 ]]; then
    if ssh buildserver "cd /repo && ./start_build.sh ..."; then
        build_successful harper_deb13_kernel
    else
        build_failed harper_deb13_kernel "remote_build_failed"
    fi
fi
```

### Option 4: Job Queue
Enqueue for batch processing:
```bash
if [[ $BUILD_NEEDED -eq 0 ]]; then
    queue build harper_deb13_kernel "$DETECTED_KERNEL_VERSION"
    # Later, when processing queue:
    # if build_succeeded; then
    #     build_successful harper_deb13_kernel
    # fi
fi
```

## Customization

### Create a New Trigger Plugin

To monitor a different upstream source (e.g., Fedora kernel), implement the three required functions:

1. **Create plugin file:** `scripts/plugins/triggers/fedora_kernel.sh`

```bash
#!/bin/bash
# Harper Foundry: Fedora Kernel Release Trigger Plugin

VERSION_TRACKING_FILE="$REPO_ROOT/version_tracking/fedora_latest_kernel.txt"
FEDORA_KOJI_API="https://koji.fedoraproject.org/koji/api/v1/..."

# REQUIRED: Detection function
fedora_kernel_trigger() {
    local force_build="${1:-}"
    
    log_info "=== Fedora Kernel Release Monitor ==="
    
    # 1. Query Fedora Koji API for latest kernel
    latest_version=$(curl -s "$FEDORA_KOJI_API" | ...)
    
    # 2. Load last built version
    source "$VERSION_TRACKING_FILE" 2>/dev/null || KERNEL_VERSION="unknown"
    
    # 3. Compare and decide
    if [[ "$latest_version" != "$KERNEL_VERSION" ] || [ "$force_build" = "true" ]]; then
        export DETECTED_KERNEL_VERSION="$latest_version"
        export DETECTED_BUILD_REASON="new_version"
        return 0  # Build needed
    fi
    
    return 1  # No action
}

# REQUIRED: Success callback
fedora_kernel_build_successful() {
    log_ok "Updating tracking for Fedora kernel $DETECTED_KERNEL_VERSION"
    
    cat > "$VERSION_TRACKING_FILE" << EOF
KERNEL_VERSION=$DETECTED_KERNEL_VERSION
LAST_BUILD_DATE=$(date -u +%Y-%m-%d)
BUILD_STATUS=success
EOF
    
    return 0
}

# REQUIRED: Failure callback
fedora_kernel_build_failed() {
    local error_info="${1:-unknown}"
    log_error "Fedora kernel build failed: $error_info"
    return 0
}
```

2. **Test locally:**
```bash
source ./scripts/plugins/triggers/runner.sh

# Test detection
check_if_build_is_needed fedora_kernel

if [[ $? -eq 0 ]]; then
    echo "Build needed: $DETECTED_KERNEL_VERSION"
fi
```

3. **Integrate into automation:**
```bash
# Add to cron_example.sh or GitHub Actions workflow
if [[ $BUILD_NEEDED -eq 0 ]]; then
    ./start_build.sh --params-file params/fedora_profile.params
    build_successful fedora_kernel
fi
```

### Change Build Profile Targeted by Trigger

Modify the detection logic in `scripts/plugins/triggers/harper_deb13_kernel.sh`:

```bash
# Change which source package to monitor in Debian backports
DEBIAN_SOURCE_PACKAGE="linux"  # Different source package name if needed

# Change which published source index to monitor
DEBIAN_BACKPORTS_SOURCES_URL="https://deb.debian.org/debian/dists/trixie-backports/main/source/Sources.xz"

# Change where to store version tracking
VERSION_TRACKING_FILE="$REPO_ROOT/version_tracking/PROFILE_NAME_latest.txt"
```

### Adjust Polling Frequency

Edit `.github/workflows/monitor-deb13-kernel.yml`:

```yaml
on:
  schedule:
    - cron: '0 */12 * * *'  # Every 12 hours
    # - cron: '0 0 * * *'    # Daily at midnight
    # - cron: '0 * * * *'    # Every hour
```

Or edit your local cron entry:

```bash
crontab -e
# Change from 10 minutes to daily (19:03 UTC):
# 3 19 * * * /path/to/cron_example.sh
```

### Create Chained Triggers

To trigger multiple kernel monitors in sequence:

```bash
source ./scripts/plugins/triggers/runner.sh

# Monitor multiple sources
trigger_build harper_deb13_kernel
trigger_build fedora_kernel  # After implementing
trigger_build custom_kernel  # If you create it
```

## Version Tracking File Format

```bash
KERNEL_VERSION=6.11.8              # Latest compiled version
LAST_BUILD_DATE=2026-02-15         # UTC date of last successful build
BUILD_STATUS=success               # success | failed | in_progress

# Optional fields for debugging:
# BUILD_DURATION_SECONDS=3600
# BUILD_LOG_URL=https://...
# UPSTREAM_VERSION_CHECKED=6.12.0
```

## Troubleshooting

### "Source index query failed"
- Check internet connectivity
- Verify Debian backports source index is accessible
- Test manually: `curl https://deb.debian.org/debian/dists/trixie-backports/main/source/Sources.xz | xz -dc | grep '^Package: linux$'`

### "Version file not found"
- Initialize: `mkdir -p version_tracking && touch version_tracking/harper_deb13_latest_kernel.txt`
- Add to git: `git add version_tracking/`
- Commit: `git commit -m "Initialize version tracking"`

### "Build not triggering"
- Check that build execution code (Step 3) is actually uncommented/implemented
- Verify function exports in runner.sh: `grep export.*build_successful /path/to/runner.sh`
- Check logs: `tail -f logs/trigger_cron.log` (cron) or `gh run view <run_id> --log` (Actions)
- Verify pipes aren't hiding errors: `check_if_build_is_needed harper_deb13_kernel 2>&1 | tee -a logfile`

### "Version tracking out of sync"
- Reset to known state: `echo "KERNEL_VERSION=6.11.8" > version_tracking/harper_deb13_latest_kernel.txt`
- Commit: `git add version_tracking/ && git commit -m "Reset version tracking"`

## Next Steps

1. **Implement build execution** (Step 3) in your orchestrator:
   - Local cron: Edit `scripts/plugins/triggers/cron_example.sh` OPTION A/B/C
   - GitHub Actions: Modify `.github/workflows/monitor-deb13-kernel.yml` build steps

2. **Test locally** before enabling automated runs:
   ```bash
   source ./scripts/plugins/triggers/runner.sh
   check_if_build_is_needed harper_deb13_kernel
   
   # If BUILD_NEEDED=0, simulate full flow:
   ./start_build.sh --params-file params/tinyconfig.params
   build_successful harper_deb13_kernel
   ```

3. **Monitor first builds** carefully:
   - Check logs: `tail -f logs/trigger_cron.log`
   - Verify version tracking updated: `cat version_tracking/harper_deb13_latest_kernel.txt`
   - Confirm second trigger doesn't rebuild same version

4. **Add notifications** (optional):
   - GitHub Actions: Use Slack/Discord actions on workflow completion
   - Cron: Email output by removing `| tee` and letting cron mail output
   - Plugin: Add notification calls to success/failure callbacks

## References

- [Debian Package Repository](https://deb.debian.org/debian/)
- [GitHub Actions Scheduling](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)
- [Cron Syntax Reference](https://crontab.guru/)
