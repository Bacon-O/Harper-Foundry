# Trigger Jobs - Automated Kernel Build Pipeline

This document describes how to set up and customize automated trigger jobs for building new kernel versions when releases become available.

## Overview

The trigger job system uses a **plugin-based architecture** to monitor upstream kernel releases (e.g., Debian Trixie Backports for Deb13) and automatically build new versions when detected. This enables:
- **Zero-downtime updates**: New kernels built immediately upon release
- **Version tracking**: Maintains history of which versions have been successfully built
- **Flexible execution**: Background builds, scheduled jobs, or manual triggers
- **Extensible design**: Add new trigger types (different upstreams) without modifying core code

## Architecture

**Diagram: <Distro> Automated Build Pipeline with Callbacks**

```
┌─────────────────────────────────────────────────────────────┐
│  Upstream Scheduler (Cron or GitHub Actions)                │
│  - Local: cron_example.sh (runs with provided schedule)     │
│  - CI: .github/workflows/monitor-deb13-kernel.yml (6h)      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Executes: check_if_build_is_needed()
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: Trigger Plugin Runner (Dispatcher)                 │
│  (scripts/plugins/triggers/runner.sh)                       │
│                                                             │
│  - Loads appropriate trigger plugin                         │
│  - Exports: DETECTED_KERNEL_VERSION, DETECTED_BUILD_REASON  │
│  - Returns: 0=build needed, 1=no action                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Calls: <distro>_kernel_trigger()
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: Trigger Detection Plugin                           │
│  (scripts/plugins/triggers/<distro>_kernel.sh)          │
│                                                             │
│  1. Query Debian backports source index for latest version  │
│  2. Load last successfully built version                    │
│  3. Compare versions                                        │
│  4. Export DETECTED_KERNEL_VERSION if new                   │
│  5. Return: 0 if build needed, 1 if not                     │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
   ┌─────────┐          ┌─────────────────┐
   │Return 1 │          │Return 0 (Build  │
   │No Action│          │Needed)          │
   │Needed   │          │                 │
   └─────────┘          └────────┬────────┘
                                  │
                 ┌────────────────┴─────────────────┐
                 │                                  │
                 ▼                                  ▼
       ┌──────────────────┐          ┌──────────────────────┐
       │STEP 3: Execute   │          │STEP 4: Success       │
       │Build (Optional)  │          │Callback              │
       │                  │          │                      │
       │./start_build.sh  │──────────▶│build_successful()   │
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

The `version_tracking/` directory maintains state for each build profile:

### 3. Trigger Plugin System

Trigger plugins live in `scripts/plugins/triggers/`:

## Customization

### Create a New Trigger Plugin

To monitor a different upstream source (e.g., Fedora kernel), implement the three required functions:

1. **Create plugin file:** `scripts/plugins/triggers/fedora_kernel.sh`

```bash
#!/bin/bash

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

- [GitHub Actions Scheduling](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)
- [Cron Syntax Reference](https://crontab.guru/)
