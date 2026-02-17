# Harper Foundry: Parameters Reference

This directory contains configuration files (params files) that define how a build should be executed.

## Available Configurations

### Full Desktop Kernel Configurations

- **`harper_deb13.params`** - Complete desktop kernel based on Debian 13 (Trixie) backports with x86-64-v3 optimizations
  - Compiler: **CLANG/LLVM** (not GCC) for modern optimization capabilities
  - Target: x86_64 with AVX2, FMA, BMI2 (Haswell+)
  - Timer: 1000Hz for low latency
  - Source: Debian Trixie Backports
  - Status: ⚠️ EXPERIMENTAL - Use at your own risk
  - Use: Enthusiast desktop builds, reference implementation

### Testing Configurations

- **`_test_overrides.params`** - **Override Pattern** for CI/testing workflows
  - Inherits from a full desktop kernel config (default: `harper_deb13.params`)
  - Overrides test-specific values (output directory, QA mode, etc.)
  - Use: GitHub workflows, preprod testing, CI builds

- **`tinyconfig.params`** - Fast minimal build for quick validation (2-5 minutes)
  - Minimal kernel configuration for speed
  - Uses kernel.org LTS source
  - Disables QEMU tests
  - Use: Quick testing, development iterations

### Templates

- **`foundry.params`** - Template with EDIT_ME placeholders
  - ⚠️ **DO NOT USE DIRECTLY** - this is a template!
  - Copy and customize to create your own build configs
  - Use: Starting point for custom configurations

- **`_example.params`** - Working example configuration
  - Complete, working reference implementation
  - Shows all available parameters with documentation
  - Use: Reference, copy as starting point

## Configuration Override Patterns

Harper Foundry provides **two methods** to override params files. Both accomplish the same goal with different approaches:

### Method 1: `-o/--overrides` Flag (Recommended for CLI)

Use the `-o` flag to apply an override params file on top of a base config:

```bash
# Base params + override params
./start_build.sh -p params/harper_deb13.params -o params/_test_overrides.params

# Works with any combination
./start_build.sh -p params/foundry.params -o params/my_overrides.params
```

**How it works:**
1. Load base params file (`-p`)
2. Apply override params file (`-o`) on top
3. Override file values replace base file values

**Use when:**
- Running builds from command line
- You want explicit, visible base + override selection
- Cleaner separation of concerns

### Method 2: `PRODUCTION_CONFIG` Environment Variable (GitHub Workflows)

The `_test_overrides.params` file uses **internal inheritance** via environment variable:

```bash
#!/bin/bash
# _test_overrides.params
# ⚠️  REQUIRED: PRODUCTION_CONFIG must be set as environment variable
if [ -z "$PRODUCTION_CONFIG" ]; then
    echo "❌ Error: PRODUCTION_CONFIG environment variable not set"
    exit 1
fi

# 1. Source the specified production config
source "$(dirname "${BASH_SOURCE[0]}")/$PRODUCTION_CONFIG"

# 2. Override specific values for testing
HOST_OUTPUT_DIR="/path/to/output/testing"
QA_MODE="ENFORCED"
BYPASS_QA="false"
```

**Usage:**
```bash
PRODUCTION_CONFIG=harper_deb13.params ./start_build.sh -p params/_test_overrides.params
```

**How it works:**
1. Override file internally sources base config via `PRODUCTION_CONFIG`
2. Override file declares its own dependency
3. Base config selection happens via environment variable

**Use when:**
- GitHub workflows with dropdown selection
- Override file wants to control its own base
- Dynamic base selection based on environment

### Benefits (Both Methods)

✅ **Maintain one source of truth** - Full desktop kernel settings in one file  
✅ **Override only what differs** - Test-specific values in override file  
✅ **Easy updates** - Change base config once, testing inherits  
✅ **Flexible deployment** - Same logic on host and in container  

### Use Cases

- **Preprod testing**: Base desktop kernel → test output directory
- **Stricter QA**: Base build → enforced QA mode
- **Version pinning**: Base "latest" → pinned version for CI
- **Output variants**: Same build → multiple output locations

### Comparison

| Feature | `-o` Flag | `PRODUCTION_CONFIG` Env Var |
|---------|-----------|-----------------------------|
| **Usage** | `./start_build.sh -p base.params -o override.params` | `PRODUCTION_CONFIG=base.params ./start_build.sh -p override.params` |
| **Best For** | Command-line usage | GitHub workflows with dropdowns |
| **Base Selection** | Explicit in command | Environment variable |
| **Clarity** | Immediately visible | Requires reading override file |
| **Flexibility** | Any file can override any base | Override file controls its own logic |

**Recommendation:** Use `-o` flag for manual builds, use `PRODUCTION_CONFIG` for CI workflows.

## GitHub Workflows

The `.github/workflows/kernel-factory.yml` workflow supports manual dispatch with dual dropdown selection:

```yaml
workflow_dispatch:
  inputs:
    base_params:
      description: 'Base Configuration'
      type: choice
      options:
        - 'tinyconfig.params'              # Fast validation (2-5 min)
        - 'harper_deb13.params'      # Full desktop kernel (experimental)
        - 'foundry.params'                 # Template (needs customization)
    
    override_mode:
      description: 'Apply Override'
      type: choice
      options:
        - 'none'
        - 'testing.params'                 # Test output dir + enforced QA
```

**Workflow Behavior:**
- ✅ Manual dispatch only (no automatic triggers)
- ✅ Dual dropdown selection for base + override
- ✅ Perfect for testing and experimentation
- ℹ️ Production pipelines run in shadow/private repo

## Creating Custom Configs

### Option 1: Copy Template

```bash
cp params/foundry.params params/my_build.params
# Edit params/my_build.params - replace all EDIT_ME values
./start_build.sh -p params/my_build.params
```

### Option 2: Override Pattern

```bash
# Create params/my_test.params
cat > params/my_test.params << 'EOF'
#!/bin/bash
# Source production config
source "$(dirname "${BASH_SOURCE[0]}")/harper_deb13.params"

# Override for testing
HOST_OUTPUT_DIR="/tmp/test-builds"
QA_MODE="RELAXED"
KERNEL_VERSION="6.12.8"  # Pin to specific version
EOF

./start_build.sh -p params/my_test.params
```

## Parameter Categories

### Core Setup (Required)
- `BUILD_WORKSPACE_DIR` - Build workspace on host (use fast storage like SSD/NVMe), mounted as /build
- `HOST_OUTPUT_DIR` - Where .deb files go
- `USE_PARAM_SCOPED_DIRS` - When true, repo-relative defaults are scoped per params name
- `DOCKERFILE_PATH` - Docker image to use
- `FOUNDRY_EXEC` - Script to run inside container

### Kernel Definition
- `TARGET_ARCH` - Architecture (x86_64, aarch64, etc.)
- `KERNEL_SOURCE` - Where to get kernel (kernel.org, debian, etc.)
- `KERNEL_VERSION` - Version or alias (latest, lts, 6.12.8)
- `DEBIAN_PACKAGE_NAME` - Output .deb package name

### Build Strategy
- `BASE_CONFIG` - Starting kernel config (defconfig, tinyconfig)
- `TUNING_CONFIG` - Additional config fragment
- `PARALLEL_JOBS` - Build jobs if left blank defaults to nproc-1 (min 1)

### Quality Assurance
- `BYPASS_QA` - Skip QA tests (true/false)
- `QA_MODE` - RELAXED or ENFORCED
- `ENABLE_QEMU_TESTS` - Boot test in QEMU (true/false)
- `QA_TESTS` - Individual test scripts
- `QA_TEST_PACKAGE` - Test package suites

## Environment Variables

You can also override params via environment variables:

```bash
# Override the base config used by _test_overrides.params
export PRODUCTION_CONFIG="my_custom_base.params"
./start_build.sh -p params/_test_overrides.params

# This sources my_custom_base.params instead of harper_deb13.params
```

**Note:** The `PRODUCTION_CONFIG` variable name refers to selecting a base configuration,
not for production systems. The Harper kernel is experimental and not suitable for production use.

## See Also

- [Main README](../README.md) - Harper Foundry overview
- [CONTRIBUTING](../CONTRIBUTING.md) - Development guidelines
- [Kernel Sources Plugin](../scripts/plugins/kernelsources/README.md) - Source strategies
