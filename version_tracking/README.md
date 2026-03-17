# Version Tracking

This directory tracks the last successfully compiled kernel versions for each build profile.

## Files

- **`harper_deb13_latest_kernel.txt`** - Last successful kernel version compiled with harper_deb13.
  - Format: 
    ```
    SOFTWARE_VERSION=6.18.12-1~bpo13+1
    LAST_BUILD_DATE=2026-02-15
    BUILD_STATUS=success
    ```
  - Stores the plain Debian source version from the backports source index
  - Updated after successful build completion
  - Used by trigger jobs to detect new releases

- **`linux_sched-ext_scx_latest.txt`** - Last successful sched-ext/scx version compiled with linux_sched_ext_scx.
  - Format:
    ```
    SOFTWARE_VERSION=v1.0.14
    LAST_BUILD_DATE=2026-03-16
    BUILD_STATUS=success
    ```
  - Stores the upstream GitHub release tag from `sched-ext/scx`
  - Updated after successful build completion
  - Used by trigger jobs to detect new releases

## Usage

These files are managed automatically by:
1. `scripts/plugins/triggers/harper_deb13_kernel.sh` - Detects new releases (via runner.sh dispatcher)
2. `scripts/plugins/triggers/linux_sched_ext_scx.sh` - Detects new sched-ext/scx tags (via runner.sh dispatcher)
3. CI/CD pipeline - Updates version after successful compilation
4. Scheduled monitoring workflows - Trigger checks and dispatch builds

Do not edit manually unless troubleshooting or resetting trigger state.
