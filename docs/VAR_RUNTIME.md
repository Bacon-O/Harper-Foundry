# Runtime State Directory (`var/runtime/`)

The `var/runtime/` directory stores persistent state files that survive multiple script invocations and environment variable resets. This eliminates boilerplate code in addon scripts.

## Purpose

When building or testing, scripts may source `env_setup.sh` multiple times. Without `var/runtime/`, each call would recalculate values (like BUILD_ID or QA build directories), making it difficult to maintain state. The `var/runtime/` approach stores the "source of truth" in files, following Unix conventions for variable/runtime data.

## Available Runtime Files

### `BUILD_ID`
The unique build identifier for this session. Remains constant across all env_setup.sh calls.
- Format: `20260217_160524` (timestamp) or `gh_XXXX` (GitHub Actions run ID)
- Usage: `BUILD_ID=$(cat ${REPO_ROOT}/var/runtime/BUILD_ID)`

### `BUILD_OUTPUT_DIR`
The absolute path where build artifacts are stored.
- Format: `/path/to/output/build_20260217_160524`
- Usage: `cat ${REPO_ROOT}/var/runtime/BUILD_OUTPUT_DIR`

### `HOST_OUTPUT_DIR`
The base output directory (parent of BUILD_OUTPUT_DIR).
- Format: `/path/to/output`
- Usage: `cat ${REPO_ROOT}/var/runtime/HOST_OUTPUT_DIR`

### `QA_BUILD_DIR` (QA-Only Mode)
When using `--qa-only`, this file stores the specific build directory to test against.
- Only written when `--qa-only` mode is active
- Usage:
  ```bash
  QA_BUILD_DIR=$(cat "${REPO_ROOT}/.runtime/QA_BUILD_DIR" 2>/dev/null || echo "")
  if [ -n "$QA_BUILD_DIR" ]; then
      # Test this specific directory
  else
      # Normal mode: find latest build
  fi
  ```

## For New Addon Developers

Instead of checking environment variables with boilerplate like:
```bash
if [ -z "$VAR" ]; then
    if [ -n "$OTHER_VAR" ]; then
        VAR="$OTHER_VAR"
    else
        VAR=$(calculate_value)
    fi
fi
```

Simply read from the `.runtime/` file:
```bash
VAR=$(cat "${REPO_ROOT}/.runtime/FILENAME" 2>/dev/null || echo "default_value")
```

## Cleanup

The `var/runtime/` directory is automatically created by `env_setup.sh` and is listed in `.gitignore`. To force a fresh runtime state, delete it:
```bash
rm -rf var/runtime/
```

The next invocation will create a new one with fresh values.

## Example: Adding a New Addon

1. **Old way** (verbose, fragile):
   ```bash
   if [ -z "$MY_VALUE" ]; then
       if [ -n "$OVERRIDE_VALUE" ]; then
           MY_VALUE="$OVERRIDE_VALUE"
       else
           MY_VALUE=$(find $HOST_OUTPUT_DIR ...)
       fi
   fi
   ```

2. **New way** (clean, maintainable):
   ```bash
   # Read from runtime state, use default if not set
   MY_VALUE=$(cat "${REPO_ROOT}/.runtime/MY_VALUE" 2>/dev/null || echo "default")
   ```

Just have `env_setup.sh` write it once, and all scripts can read it.
