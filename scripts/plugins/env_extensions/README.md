# Environment Extensions

This directory allows you to **extend and customize environment variables after core setup, without modifying the core `env_setup.sh`**.

## Overview

**The Pattern:**
1. Main `env_setup.sh` runs and configures the core environment
2. Each executable `.sh` script in this directory is automatically sourced
3. Your custom scripts can override, extend, or add environment variables
4. All changes are applied transparently before the build starts

## Quick Start

### Using the ENV_EXTENSIONS Parameter (Recommended)

**Control exactly which extensions load, and in what order, via your params file:**

1. **Edit your params file** (e.g., `params/harper_deb13.params`):
   ```bash
   # --- Environment Extensions ---
   # Load custom extensions in a specific order
   ENV_EXTENSIONS=(
       "container_optimized.sh"
       "my_debug_mode.sh"
   )
   ```

2. **Create your custom extensions:**
   ```bash
   cat > scripts/scripts.d/plugins/env_extensions/container_optimized.sh << 'EOF'
   #!/bin/bash
   export PARALLEL_JOBS=16
   export DOCKER_MEMORY_LIMIT="8g"
   echo "🐳 Container optimizations enabled"
   EOF
   chmod +x scripts/scripts.d/plugins/env_extensions/container_optimized.sh
   ```

3. **Run the build** - your specified extensions load in order:
   ```bash
   source scripts/env_setup.sh
   # Output:
   # 🔧 Loading extension: container_optimized.sh (custom)
   # 🐳 Container optimizations enabled
   ```

**Key Benefits:**
- ✅ Explicit control: Specify exactly which extensions load
- ✅ Ordered execution: Load extension A before B (dependencies work)
- ✅ Per-build profiles: Different params files = different extension stacks
- ✅ Smart lookup: Custom (`scripts/scripts.d/plugins/`) takes precedence over official (`scripts/plugins/`)

### Create a Custom Setup

1. **Create a new script:**
   ```bash
   cat > scripts/scripts.d/plugins/env_extensions/my_custom_setup.sh << 'EOF'
   #!/bin/bash
   # My custom environment setup
   export PARALLEL_JOBS=32
   export CUSTOM_BUILD_FLAG="true"
   echo "🔧 My custom environment loaded"
   EOF
   ```

2. **Make it executable:**
   ```bash
   chmod +x scripts/scripts.d/plugins/env_extensions/my_custom_setup.sh
   ```

3. **Run env_setup.sh** - your script loads automatically:
   ```bash
   source scripts/env_setup.sh
   # Output: 🔧 My custom environment loaded
   ```

### Examples

#### Container-Optimized Build

```bash
#!/bin/bash
# Optimize for Docker container builds
export PARALLEL_JOBS=16
export DOCKER_MEMORY_LIMIT="8g"
export DOCKER_CPU_LIMIT="16"
echo "🐳 Container optimizations enabled"
```

#### Development/Debug Mode

```bash
#!/bin/bash
# Enable debug output and verbose logging
export DEBUG_MODE="true"
export VERBOSE_BUILD="true"
export SHELL_DEBUG="set -x"  # Enable bash debug mode
echo "🐛 Debug mode enabled - verbose output active"
```

#### ARM64-Specific Setup

```bash
#!/bin/bash
# Customizations for ARM64 hosts
if [[ "$(uname -m)" = "aarch64" ]]; then
    export PARALLEL_JOBS=8  # Conservative for ARM64
    export QEMU_STATIC_PATH="/usr/bin/qemu-x86_64-static"
    echo "⚙️ ARM64 host optimizations applied"
fi
```

#### CI/CD Pipeline Setup

```bash
#!/bin/bash
# Optimized settings for GitHub Actions / CI pipelines
export CI_MODE="true"
export BYPASS_QA="false"
export QA_MODE="ENFORCED"
export PARALLEL_JOBS=$(nproc)
export BUILD_TIMEOUT=7200
echo "🚀 CI/CD pipeline mode enabled"
```

## Features

✅ **Smart Discovery**
- All executable `.sh` files are automatically sourced
- Scripts run in alphabetical order (use numeric prefixes to control order)
- No configuration needed - just create and `chmod +x`

✅ **No Git Conflicts**
- This directory is gitignored
- Your customizations stay local and won't conflict during `git pull`

✅ **Composable**
- Create multiple scripts for different purposes
- Scripts can work together to build up complex setups
- Easy to swap different profiles for different builds

✅ **Transparent**
- Your scripts run AFTER main `env_setup.sh` completes
- Can override any variables from main setup
- Output shows which custom scripts loaded

## Loading Modes

### Mode 1: No Extensions (Default)

```bash
# ENV_EXTENSIONS not set
# OR
ENV_EXTENSIONS=()
```

**Behavior:**
- No environment extensions are loaded
- Build proceeds with core setup only
- Clean, minimal approach

### Mode 2: Explicit Extensions

```bash
ENV_EXTENSIONS=(
    "container_optimized.sh"
    "my_production_flags.sh"
)
```

**Behavior:**
- Loads only the specified extensions
- In the exact order specified
- Custom extensions checked first (takes precedence)
- Official versions used if custom not found
- Warning issued if extension not found

**When to use:**
- You want explicit control over what loads
- You need scripts to run in a specific order
- Setting up different profiles for different builds
- Production deployments where reproducibility matters

## Advanced Usage

### Controlling Script Order

Use numeric prefixes to ensure your scripts run in a specific order:

```bash
./scripts/scripts.d/plugins/env_extensions/10_base_customization.sh
./scripts/scripts.d/plugins/env_extensions/20_ci_specific.sh
./scripts/scripts.d/plugins/env_extensions/30_debug_options.sh
```

They'll source in that order regardless of alphabetical filename.

### Conditional Logic

Your scripts can check the environment and apply settings conditionally:

```bash
#!/bin/bash
# Load different settings based on params file

if [[ "$(basename "$PARAMS_FILE")" = "harper_deb13.params" ]]; then
    export OPTIMIZED_FOR_DEB13="true"
    echo "🔧 Debian 13 optimizations applied"
elif [[ "$(basename "$PARAMS_FILE")" = "tinyconfig.params" ]]; then
    export MINIMAL_BUILD="true"
    echo "🔧 Minimal build mode"
fi
```

### Accessing Main Environment

Your custom scripts can reference any variables already set by the main `env_setup.sh`:

```bash
#!/bin/bash
# Use variables from main setup
echo "Repo root: $REPO_ROOT"
echo "Target architecture: $TARGET_ARCH"
echo "Params file: $PARAMS_FILE"
echo "Build output: $BUILD_OUTPUT_DIR"

# Extend based on main setup
if [[ "$TARGET_ARCH" = "arm64" ]]; then
    export ARM64_SPECIFIC="yes"
fi
```

## Common Patterns

### Per-Build-Type Setup

Create separate scripts for different build scenarios:

```bash
# For quick test builds: 10_test_env.sh
if [[ "$PARAMS_FILE" == *"tinyconfig"* ]]; then
    export PARALLEL_JOBS=4
    export TEST_MODE="true"
fi

# For full builds: 20_production_env.sh
if [[ "$PARAMS_FILE" == *"harper_deb13"* ]]; then
    export PARALLEL_JOBS=16
    export PRODUCTION_BUILD="true"
fi
```

### Per-Host Setup

Detect the host and apply appropriate settings:

```bash
#!/bin/bash
HOST_CPU=$(nproc)
if [[ "$HOST_CPU" -gt 16 ]]; then
    export PARALLEL_JOBS=16
elif [[ "$HOST_CPU" -gt 8 ]]; then
    export PARALLEL_JOBS=8
else
    export PARALLEL_JOBS=$((HOST_CPU - 1))
fi
```

### Feature Flags

Use environment variables to toggle features on-demand:

```bash
#!/bin/bash
# Allow users to enable experimental features via env var
: "${ENABLE_CCACHE:=false}"
if [[ "$ENABLE_CCACHE" = "true" ]]; then
    export CCACHE_DIR="${REPO_ROOT}/.build-cache"
    export CCACHE_MAXSIZE="5G"
    mkdir -p "$CCACHE_DIR"
    echo "💾 Build cache enabled"
fi
```

Then users can easily enable it:
```bash
ENABLE_CCACHE=true ./start_build.sh
```

## Best Practices

1. **Start with comments** - Explain what your script customizes
2. **Use defensive syntax** - Check if variables exist before overriding
3. **Be explicit** - Use `export` to ensure variables propagate
4. **Give feedback** - Print what your script is doing (helps debugging)
5. **Keep it simple** - Each script should handle one concern
6. **Use numeric prefixes** - If order matters, make it obvious with `10_`, `20_`, etc.
7. **Document assumptions** - Note any required params or environment state

## Troubleshooting

### Script not running?
- Check it's executable: `ls -l scripts/scripts.d/plugins/env_extensions/`
- Verify the filename ends with `.sh`
- Ensure `chmod +x` was applied
- Check for syntax errors: `bash -n your_script.sh`

### Variables not being set?
- Add `echo` statements to verify your script runs
- Ensure you use `export` to make variables available downstream
- Check the order - scripts run alphabetically, so dependencies may matter
- Verify you're setting variables correctly (no typos/spaces)

### Want to debug what's loading?
- Run `bash -x scripts/env_setup.sh` to see all execution
- Add `echo` statements to see what's happening in your custom scripts

## Examples in This Directory

- `EXAMPLE-container_optimized.sh` - Shows typical custom setup structure

Remove the `EXAMPLE-` prefix and customize for your needs!

## See Also

- [env_setup.sh](../../env_setup.sh) - Main environment setup script
- [plugins/ directory](../../) - Other plugin systems (kernel sources, notifiers, patches, QA)
