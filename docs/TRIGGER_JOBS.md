# Trigger Jobs - Automated Kernel Build Pipeline

This document describes how to set up and customize automated trigger jobs for building new kernel versions when releases become available.

**Example Implementation:** This guide uses the **Harper Alloy Deb13** build profile as the reference example, demonstrating automated builds triggered by Debian Trixie Backports kernel releases.

## Overview

The trigger job system uses a **plugin-based architecture** to monitor upstream kernel releases (e.g., Debian Trixie Backports for Alloy Deb13) and automatically build new versions when detected. This enables:
- **Zero-downtime updates**: New kernels built immediately upon release
- **Version tracking**: Maintains history of which versions have been successfully built
- **Flexible execution**: Background builds, scheduled jobs, or manual triggers
- **Extensible design**: Add new trigger types (different upstreams) without modifying core code

## Architecture

**Diagram: Alloy Deb13 Automated Build Pipeline**

```
┌─────────────────────────────────────────────────────────────┐
│  Upstream Kernel Source                                     │
│  (Debian Salsa API / Trixie-Backports)                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Poll every 6 hours
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  GitHub Actions Workflow                                    │
│  (.github/workflows/monitor-deb13-kernel.yml)              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Executes: source runner.sh && trigger_build
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Trigger Plugin Runner (Plugin Dispatcher)                  │
│  (scripts/plugins/triggers/runner.sh)                       │
│                                                             │
│  - Loads appropriate trigger plugin                         │
│  - Routes to: alloy_deb13_kernel_trigger() function              │
│  - Manages environment and logging                          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Calls alloy_deb13_kernel_trigger()
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Trigger Plugin: Debian Trixie Kernel Monitor              │
│  (scripts/plugins/triggers/alloy_deb13_kernel.sh)               │
│                                                             │
│  1. Query Debian Salsa API                                  │
│  2. Load last compiled version                              │
│  3. Compare versions                                        │
│  4. Trigger build if new version detected                   │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
   ┌─────────┐          ┌─────────────────┐
   │No Action │          │Trigger Build    │
   │Needed    │          │(Placeholder)    │
   └─────────┘          └────────┬────────┘
                                  │
                 ┌────────────────┼────────────────┐
                 │                │                │
                 ▼                ▼                ▼
            ┌─────────┐    ┌──────────┐    ┌──────────┐
            │GitHub   │    │Docker    │    │Remote    │
            │Actions  │    │Local     │    │SSH Build │
            └────┬────┘    └────┬─────┘    └────┬─────┘
                 │              │              │
                 └──────────────┬──────────────┘
                                │
                                ▼
                      ┌──────────────────┐
                      │Build Complete    │
                      │Update Tracking   │
                      │File              │
                      └──────────────────┘
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

**Example: Alloy Deb13**
```
version_tracking/
├── README.md                        # This directory's documentation
└── alloy_deb13_latest_kernel.txt    # Last successful kernel version (Alloy Deb13)
    ├── KERNEL_VERSION=6.11.8
    ├── LAST_BUILD_DATE=2026-02-15
    └── BUILD_STATUS=success
```

### 3. Trigger Plugin System

Trigger plugins live in `scripts/plugins/triggers/`:

**Example: Alloy Deb13 plugin**
```
scripts/plugins/triggers/
├── runner.sh                 # Main dispatcher (routes to plugins)
├── alloy_deb13_kernel.sh     # Debian Trixie kernel monitor plugin (EXAMPLE)
└── README.md                # Plugin system documentation
```

### 4. GitHub Actions Workflow

The workflow `.github/workflows/monitor-deb13-kernel.yml` (configured for Alloy Deb13) runs on:
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
# Load the trigger plugin runner and execute (Alloy Deb13 example)
source ./scripts/plugins/triggers/runner.sh
trigger_build alloy_deb13_kernel

# Force build regardless of version:
trigger_build alloy_deb13_kernel --force
```

## Implementation: The Placeholder

The trigger plugin includes a **PLACEHOLDER** for the actual build execution. This is intentional - implementation depends on your infrastructure:

**Note:** The examples below use Alloy Deb13 configuration, but the same pattern applies to other build profiles.

### Option 1: GitHub Actions Dispatch
Trigger the main CI/CD pipeline:
```bash
gh workflow run ci-build.yml \
  -f config_file=params/harper_alloy_deb13.params \
  -f kernel_version=latest
```

### Option 2: Local Docker Build
Execute immediately:
```bash
./start_build.sh --params-file params/harper_alloy_deb13.params \
                 --kernel-version latest
```

### Option 3: Remote SSH Build
Delegate to a build server:
```bash
ssh buildserver 'cd /path/to/harper && \
  ./start_build.sh --params-file params/harper_alloy_deb13.params'
```

### Option 4: Job Queue
Add to a queue for batch processing:
```bash
# Example: Enqueue to Redis or local queue
redis-cli LPUSH "kernel_builds" "kernel_version:latest:config:harper_alloy_deb13"
```

## Customization

### Create a New Trigger Plugin

To monitor a different upstream source (e.g., Fedora kernel):

1. **Create plugin file:** `scripts/plugins/triggers/fedora_kernel.sh`

```bash
#!/bin/bash
# Harper Foundry: Fedora Kernel Release Trigger Plugin

fedora_kernel_trigger() {
    local force_build="${1:-}"
    
    log_info "=== Fedora Kernel Release Monitor ==="
    
    # Your custom logic here:
    # 1. Query Fedora package APIs
    # 2. Load last compiled version
    # 3. Compare versions
    # 4. Trigger build if new
    
    log_ok "Fedora kernel trigger executed"
}
```

2. **Make executable:**
```bash
chmod +x scripts/plugins/triggers/fedora_kernel.sh
```

3. **Test locally:**
```bash
source ./scripts/plugins/triggers/runner.sh
trigger_build fedora_kernel
```

### Change Target Build Profile

Modify `scripts/plugins/triggers/alloy_deb13_kernel.sh`:

```yaml
on:
  schedule:
    - cron: '0 */12 * * *'  # Every 12 hours
    # - cron: '0 0 * * *'    # Daily at midnight
    # - cron: '0 * * * *'    # Every hour
```

### Adjust Polling Frequency

Edit `.github/workflows/monitor-deb13-kernel.yml`:

```bash
# Update the version tracking file path or profile name:
BUILD_CONFIG="params/PROFILE_NAME.params"
VERSION_TRACKING_FILE="path/to/tracking/file.txt"
```

### Create Chained Triggers

To trigger multiple kernel monitors in sequence:

```bash
source ./scripts/plugins/triggers/runner.sh

# Monitor multiple sources
trigger_build alloy_deb13_kernel
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

### "API query failed"
- Check internet connectivity
- Verify Debian Salsa API is accessible
- Test manually: `curl https://salsa.debian.org/api/v4/projects/debian%2Flinux/repository/branches`

### "Version file not found"
- Initialize: `mkdir -p version_tracking && touch version_tracking/alloy_deb13_latest_kernel.txt`
- Add to git: `git add version_tracking/`
- Commit: `git commit -m "Initialize version tracking"`

### "Build not triggering"
- Check that the placeholder code has been replaced with actual implementation
- Verify `GITHUB_TOKEN` or credentials are configured if using remote build
- Check logs: `gh run view <run_id> --log`

### "Version tracking out of sync"
- Reset to known state: `echo "KERNEL_VERSION=6.11.8" > version_tracking/alloy_deb13_latest_kernel.txt`
- Commit: `git add version_tracking/ && git commit -m "Reset version tracking"`

## Next Steps

1. **Replace the placeholder** in `scripts/plugins/triggers/alloy_deb13_kernel.sh` with your build execution method
2. **Test locally** before enabling automated workflow:
   ```bash
   source ./scripts/plugins/triggers/runner.sh
   trigger_build alloy_deb13_kernel
   ```
3. **Monitor first builds** carefully to ensure version tracking updates correctly
4. **Add notifications** (optional) - Email, Slack, Discord updates on build completion

## References

- [Debian Salsa Project API](https://docs.gitlab.com/ee/api/)
- [GitHub Actions Scheduling](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)
- [Cron Syntax Reference](https://crontab.guru/)
