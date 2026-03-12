# Version Tracking

This directory tracks the last successfully compiled kernel versions for each build profile.

## Files

- **`harper_deb13_latest_kernel.txt`** - Last successful kernel version compiled with harper_deb13.
  - Format: 
    ```
    KERNEL_VERSION=6.11.8
    LAST_BUILD_DATE=2026-02-15
    BUILD_STATUS=success
    ```
  - Updated after successful build completion
  - Used by trigger jobs to detect new releases

## Usage

These files are managed automatically by:
1. `scripts/plugins/triggers/harper_deb13_kernel.sh` - Detects new releases (via runner.sh dispatcher)
2. CI/CD pipeline - Updates version after successful compilation
3. `.github/workflows/monitor-deb13-kernel.yml` - Scheduled monitoring job

Do not edit manually unless troubleshooting or resetting trigger state.
