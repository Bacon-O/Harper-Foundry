# Override Params: Usage Guide

## Overview

**Harper Deb13** is the main production configuration, compiled with **CLANG/LLVM** for modern optimization capabilities.

Harper Foundry supports **two methods** for applying override params files:

1. **`-o/--overrides` flag** - Explicit base + override (recommended for CLI)
2. **`PRODUCTION_CONFIG` env var** - Override file sources its own base (recommended for GitHub workflows)

Both methods let you:
- Maintain one production-ready config with all kernel settings
- Override only test-specific values (output paths, QA modes, etc.)
- Keep configurations DRY (Don't Repeat Yourself)

## Method 1: `-o/--overrides` Flag

### Local Testing

```bash
# Apply override on top of base params
./start_build.sh -p params/harper_deb13.params -o params/_test_overrides.params

# Works with any params combination
./start_build.sh -p params/foundry_template.params -o params/my_custom_overrides.params

# Can be used with other flags
./start_build.sh -p params/tinyconfig.params -o params/_test_overrides.params -t --shell
```

**Advantages:**
- ✅ Explicit and clear - see both files in command
- ✅ Flexible - any file can override any base
- ✅ No environment variables needed
- ✅ Easy to understand and debug

**Example Override File:**
```bash
# params/my_overrides.params
# This file only contains the values you want to override
HOST_OUTPUT_DIR="/tmp/custom-build"
QA_MODE="ENFORCED"
KERNEL_VERSION="6.12.8"
```

## Method 2: `PRODUCTION_CONFIG` Environment Variable

### Local Testing

```bash
# Override file sources base via PRODUCTION_CONFIG
PRODUCTION_CONFIG="harper_deb13.params" ./start_build.sh -p params/_test_overrides.params

# Use different base
PRODUCTION_CONFIG="tinyconfig.params" ./start_build.sh -p params/_test_overrides.params
```

**Advantages:**
- ✅ Override file controls its own dependencies
- ✅ Great for GitHub workflow dropdowns
- ✅ Base selection is dynamic
- ✅ Override logic lives in the override file

**Example Override File:**
```bash
# params/_test_overrides.params
#!/bin/bash
# ⚠️  Requires PRODUCTION_CONFIG environment variable
if [ -z "$PRODUCTION_CONFIG" ]; then
    echo "❌ Error: PRODUCTION_CONFIG environment variable not set"
    exit 1
fi

# 1. Source the base config
source "$(dirname "${BASH_SOURCE[0]}")/$PRODUCTION_CONFIG"

# 2. Override specific values
HOST_OUTPUT_DIR="/path/to/output/testing"
QA_MODE="ENFORCED"
BYPASS_QA="false"
```

**Result:**
- ✅ Inherits all kernel settings from production (x86-64-v3, 1000Hz, etc.)
- ✅ Overrides output directory to `/path/to/output/testing`
- ✅ Enforces stricter QA mode for testing builds
- ✅ Easy to maintain - update production config once, testing inherits changes

## Which Method Should I Use?

| Scenario | Recommended Method | Example |
|----------|-------------------|----------|
| **Command-line builds** | `-o` flag | `./start_build.sh -p base.params -o overrides.params` |
| **GitHub workflow with dual dropdown** | `PRODUCTION_CONFIG` | Dropdown selects base, passes via env var |
| **Testing multiple bases locally** | `-o` flag | Easy to switch: `-p base1.params -o test.params` |
| **CI with fixed override logic** | `PRODUCTION_CONFIG` | Override file encapsulates its dependencies |
| **Quick overrides** | `-o` flag | Create simple override file, apply to any base |
| **Complex inheritance chains** | `PRODUCTION_CONFIG` | Override file can have logic, validation |

## GitHub Workflow Examples

### Example 1: Using `-o` Flag (Dual Dropdown Pattern)

```yaml
name: Test Build with Overrides
on:
  workflow_dispatch:
    inputs:
      base_params:
        description: 'Base Configuration'
        type: choice
        required: true
        default: 'harper_deb13.params'
        options:
          - 'harper_deb13.params'
          - 'foundry_template.params'
          - 'tinyconfig.params'
      
      override_mode:
        description: 'Apply Override'
        type: choice
        required: true
        default: 'none'
        options:
          - 'none'
          - '_test_overrides.params'
          - 'custom_overrides.params'

jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      
      - name: Build Kernel
        run: |
          if [[ "${{ inputs.override_mode }}" != "none" ]]; then
            # Use -o flag to apply override
            ./start_build.sh -p params/${{ inputs.base_params }} -o params/${{ inputs.override_mode }}
          else
            # Use base params only
            ./start_build.sh -p params/${{ inputs.base_params }}
          fi
```

**Advantages:**
- User sees both base and override selection in UI
- Clear, explicit selection
- Any base can be combined with any override

### Example 2: Using `PRODUCTION_CONFIG` (Environment Variable Pattern)

```yaml
name: Multi-Config Testing
on:
  workflow_dispatch:
    inputs:
      production_base:
        description: 'Production config to test'
        type: choice
        options:
          - 'harper_deb13.params'
          - 'tinyconfig.params'
          - 'my_custom_production.params'

jobs:
  test-build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      
      - name: Test Build with Override
        env:
          PRODUCTION_CONFIG: ${{ inputs.production_base }}
        run: |
          echo "Testing with base: $PRODUCTION_CONFIG"
          ./scripts/launch.sh --params-file params/_test_overrides.params
```

**This workflow:**
- Lets you select which production config to test
- Uses `_test_overrides.params` to apply test-specific overrides
- Outputs to `/testing` directory instead of `/release`
- Runs with ENFORCED QA mode

### Example 3: Matrix Testing (Multiple Bases)

```yaml
name: Compatibility Matrix
on:
  pull_request:
  push:
    branches: [main, dev]

jobs:
  matrix-test:
    runs-on: self-hosted
    strategy:
      matrix:
        base_config:
          - harper_deb13.params
          - tinyconfig.params
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Test ${{ matrix.base_config }}
        env:
          PRODUCTION_CONFIG: ${{ matrix.base_config }}
        run: |
          ./scripts/launch.sh --params-file params/_test_overrides.params
```

**This workflow:**
- Tests multiple base configs on every PR
- Each matrix job uses a different base config
- All use the same testing overrides (output dir, QA mode)
- Ensures changes work across all configurations

### Example 4: Environment-Specific Overrides

```yaml
name: Environment Testing
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options:
          - preprod
          - staging
          - test

jobs:
  deploy-test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      
      - name: Build for ${{ inputs.environment }}
        run: |
          # Create temporary override params
          cat > params/_env_override.params << EOF
          #!/bin/bash
          source "$(dirname "${BASH_SOURCE[0]}")/harper_deb13.params"
          HOST_OUTPUT_DIR="/path/to/output/${{ inputs.environment }}"
          QA_MODE="ENFORCED"
          KERNEL_VERSION="6.12.8"  # Pin for reproducibility
          EOF
          
          ./scripts/launch.sh --params-file params/_env_override.params
```

## Advanced: Per-Environment Params Files

Instead of one `_test_overrides.params`, you can create multiple override files:

```bash
# params/_preprod.params
source "$(dirname "${BASH_SOURCE[0]}")/harper_deb13.params"
HOST_OUTPUT_DIR="/path/to/output/preprod"
QA_MODE="ENFORCED"
KERNEL_VERSION="latest"

# params/_staging.params  
source "$(dirname "${BASH_SOURCE[0]}")/harper_deb13.params"
HOST_OUTPUT_DIR="/path/to/output/staging"
QA_MODE="RELAXED"
KERNEL_VERSION="6.12.8"  # Pinned for stability

# params/_qa.params
source "$(dirname "${BASH_SOURCE[0]}")/harper_deb13.params"
HOST_OUTPUT_DIR="/path/to/output/qa"
QA_MODE="ENFORCED"
ENABLE_QEMU_TESTS="true"  # Full QEMU boot testing
```

Then in workflow:

```yaml
config_file:
  type: choice
  options:
    - 'params/_preprod.params'
    - 'params/_staging.params'
    - 'params/_qa.params'
```

## Benefits

### Single Source of Truth
- Production kernel config in one file (`harper_deb13.params`)
- All kernel settings, patches, optimizations defined once
- Testing/staging/preprod all inherit automatically

### Easy Maintenance
- Update scheduler settings → all environments get it
- Change kernel version → update one file
- Modify kernel config → propagates to all override files

### Flexibility
- Override only what differs per environment
- Use env vars to switch base configs
- Create as many override files as needed

### GitHub Workflow Friendly
- Dropdown menus for environment selection
- Matrix testing across multiple configs
- Environment-specific builds from same source

## Current Workflow Integration

The `kernel-factory.yml` workflow is **manual dispatch only** (perfect for a public reference repo):
- Dual dropdown for base config selection
- Optional testing overrides
- Perfect for experimentation and testing
- Production pipelines run in shadow/private repo
  
  workflow_dispatch:
    inputs:
      config_file:
        options:
          - 'params/tinyconfig.params'     # Fast (2-5 min)
          - 'params/_test_overrides.params'       # Full test build
          - 'params/foundry_template.params'        # Production
```

## See Also

- [params/README.md](README.md) - Complete params reference
- [.github/workflows/kernel-factory.yml](../.github/workflows/kernel-factory.yml) - Current workflow
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Development guidelines
