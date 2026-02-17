# GitHub Actions: Dual Dropdown Workflow

This document explains the **dual dropdown system** for GitHub Actions workflows that provides flexible parameter configuration with optional testing overrides.

## Quick Reference

### Workflow UI Dropdowns

```
┌─────────────────────────────────────────┐
│ Dropdown 1: Base Configuration         │
├─────────────────────────────────────────┤
│ • tinyconfig.params                     │
│ • harper_deb13.params                   │
│ • foundry.params                        │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Dropdown 2: Apply Override              │
├─────────────────────────────────────────┤
│ • none                                  │
│ • testing.params (test dir + QA)        │
└─────────────────────────────────────────┘
```

### Common Combinations

| Base Config | Override | Build Time | Use Case |
|------------|----------|-----------|----------|
| `tinyconfig.params` | `none` | 2-5 min | Quick validation / CI |
| `harper_deb13.params` | `none` | Full build | Production release |
| `harper_deb13.params` | `testing.params` | Full build | Preprod testing |
| `tinyconfig.params` | `testing.params` | 2-5 min | CI with enforced QA |

## How to Use

### Via GitHub Actions UI

1. Go to **Actions** → **Harper Kernel Factory** → **Run workflow**
2. Select **Base Configuration** (e.g., `harper_deb13.params`)
3. Select **Apply Override** (`none` or `testing.params`)
4. Click **Run workflow**

### Locally

```bash
# No override
./start_build.sh -p params/harper_deb13.params

# With testing override (PRODUCTION_CONFIG is REQUIRED)
PRODUCTION_CONFIG=harper_deb13.params \
  ./start_build.sh -p params/_test_overrides.params
```

## Common Workflows

### 1. Fast Validation (2-5 minutes)

```
Base Configuration: tinyconfig.params
Apply Override: none
```

**Result:**
- Minimal kernel build for quick testing
- Uses kernel.org LTS source
- Tinyconfig base (minimal features)
- Perfect for CI/PR validation

### 2. Preprod Testing

```
Base Configuration: harper_deb13.params
Apply Override: testing.params (test output dir + enforced QA)
```

**Result:**
- Full production settings (x86-64-v3, 1000Hz, Debian Trixie)
- Output to `/testing` directory (not `/release`)
- ENFORCED QA mode (stricter than production)
- Perfect for pre-release testing

### 3. Production Release

```
Base Configuration: harper_deb13.params
Apply Override: none
```

**Result:**
- Exact production build
- All production settings
- Output to production directory
- RELAXED QA mode (warnings don't fail)
- Use for actual releases

## Detailed Behavior

### Option 1: Direct Execution (Override = "none")

```
Base: harper_deb13.params
Override: none

→ Executes: params/harper_deb13.params
→ Output: /path/to/output/release/harper-deb13/
→ QA Mode: RELAXED (from original params)
```

### Option 2: Override Mode (Override = "testing.params")

```
Base: harper_deb13.params
Override: testing.params

→ Sets: PRODUCTION_CONFIG=harper_deb13.params
→ Executes: params/_test_overrides.params
→ _test_overrides.params:
  • Sources: harper_deb13.params (via $PRODUCTION_CONFIG)
  • Overrides:
    - Output: /path/to/output/testing
    - QA Mode: ENFORCED
    - Bypass QA: false
```

## Technical Flow

### Workflow Job Execution

```yaml
jobs:
  preheat:
    steps:
      - name: Configure Arguments
        run: |
          if [[ "$OVERRIDE_MODE" == "testing.params"* ]]; then
            FILE="params/_test_overrides.params"
            ENV_VARS="PRODUCTION_CONFIG=$BASE_PARAMS"
          else
            FILE="params/$BASE_PARAMS"
            ENV_VARS=""
          fi
```

### Environment Variable Propagation

```yaml
preheat:
  outputs:
    args: --params-file params/_test_overrides.params
    env_vars: PRODUCTION_CONFIG=harper_deb13.params

smelt:
  needs: preheat
  steps:
    - name: Ignition
      env:
        PRODUCTION_CONFIG: harper_deb13.params  # From preheat
      run: |
        PRODUCTION_CONFIG=harper_deb13.params \
          bash ./scripts/furnace_ignite.sh --params-file params/_test_overrides.params
```

### Inside _test_overrides.params

```bash
#!/bin/bash
# Source the specified production base config
PRODUCTION_CONFIG="${PRODUCTION_CONFIG:-harper_deb13.params}"
source "$(dirname "${BASH_SOURCE[0]}")/$PRODUCTION_CONFIG"

# Apply testing-specific overrides
HOST_OUTPUT_DIR="/path/to/output/testing"
QA_MODE="ENFORCED"
BYPASS_QA="false"
```

## Workflow UI Mockup

When you trigger a manual workflow, you'll see:

```
┌─────────────────────────────────────────┐
│ Run workflow                            │
├─────────────────────────────────────────┤
│ Use workflow from: Branch: alpha-rc1   │
│                                         │
│ Base Configuration ▼                    │
│ ┌─────────────────────────────────┐    │
│ │ tinyconfig.params               │    │
│ │ harper_deb13.params             │    │
│ │ foundry.params                  │    │
│ └─────────────────────────────────┘    │
│                                         │
│ Apply Override ▼                        │
│ ┌─────────────────────────────────┐    │
│ │ none                            │    │
│ │ testing.params (test + QA)      │    │
│ └─────────────────────────────────┘    │
│                                         │
│                    [Run workflow]       │
└─────────────────────────────────────────┘
```

## Automatic Triggers (No Dropdowns)

When code is pushed (not manual dispatch), the workflow auto-selects configs:

| Trigger | Configuration Used |
|---------|-------------------|
| Push to `main` | `params/_test_overrides.params` (full test build) |
| Push to `dev` | `params/tinyconfig.params` (fast validation) |
| Push to `feature/*` | `params/tinyconfig.params` (fast validation) |
| Tag `v*` on `main` | `params/foundry.params` (production release) |

## Execution Examples

### Example 1: No Override
```
Dropdown 1: harper_deb13.params
Dropdown 2: none

Workflow executes:
  bash ./scripts/furnace_ignite.sh --params-file params/harper_deb13.params

Result:
  • Sources: params/harper_deb13.params
  • Output: /path/to/output/release/harper-deb13/
  • QA Mode: RELAXED (from original params)
```

### Example 2: With Testing Override
```
Dropdown 1: harper_deb13.params
Dropdown 2: testing.params (test output dir + enforced QA)

Workflow executes:
  PRODUCTION_CONFIG=harper_deb13.params \
    bash ./scripts/furnace_ignite.sh --params-file params/_test_overrides.params

Result:
  • _test_overrides.params sources: harper_deb13.params
  • Output: /path/to/output/testing (overridden)
  • QA Mode: ENFORCED (overridden)
  • Bypass QA: false (overridden)
```

## Local Testing

Test the same logic locally:

```bash
# No override
./start_build.sh -p params/harper_deb13.params

# With testing override
PRODUCTION_CONFIG=harper_deb13.params \
  ./start_build.sh -p params/_test_overrides.params

# ⚠️  This will ERROR (PRODUCTION_CONFIG not set):
./start_build.sh -p params/_test_overrides.params
```

## Advanced: Creating Additional Override Profiles

You can create multiple override profiles for different environments:

```bash
# params/_staging.params
source "$(dirname "${BASH_SOURCE[0]}")/${PRODUCTION_CONFIG:-harper_deb13.params}"
HOST_OUTPUT_DIR="/path/to/output/staging"
QA_MODE="RELAXED"
KERNEL_VERSION="6.12.8"  # Pinned for stability

# params/_preprod.params
source "$(dirname "${BASH_SOURCE[0]}")/${PRODUCTION_CONFIG:-harper_deb13.params}"
HOST_OUTPUT_DIR="/path/to/output/preprod"
QA_MODE="ENFORCED"
ENABLE_QEMU_TESTS="true"
```

Then add to workflow:

```yaml
override_mode:
  description: 'Apply Override'
  options:
    - 'none'
    - 'testing.params (test output + enforced QA)'
    - 'staging.params (stable version + relaxed QA)'
    - 'preprod.params (full QEMU testing)'
```

## Benefits

### For Testing
✅ Test production config without modifying it  
✅ Separate output directories (preprod vs production)  
✅ Stricter QA for testing builds  
✅ Same kernel settings, different delivery location  

### For CI/CD
✅ Matrix testing with different bases  
✅ Environment-specific builds (staging, preprod, test)  
✅ Version pinning for reproducible tests  
✅ Fast feedback with tinyconfig, thorough testing with full config  

### For Maintenance
✅ Single source of truth for production settings  
✅ Easy to add new override profiles  
✅ No duplicate configuration files  
✅ Clear separation between kernel config and build parameters  

## Troubleshooting

### Error: PRODUCTION_CONFIG environment variable not set

**Problem:** When running `_test_overrides.params`, you get:
```
❌ Error: PRODUCTION_CONFIG environment variable not set
```

**Solution:** `_test_overrides.params` is an override file that requires a base config. You must specify which production params to use:

```bash
# Correct usage
PRODUCTION_CONFIG=harper_deb13.params ./start_build.sh -p params/_test_overrides.params

# Wrong usage (will error)
./start_build.sh -p params/_test_overrides.params
```

### Override not applied

**Check:**
1. Verify workflow logs show override configuration
2. Check `env_vars` output contains `PRODUCTION_CONFIG=...`
3. Ensure `_test_overrides.params` correctly sources `$PRODUCTION_CONFIG`

### Wrong base params sourced

**Solution:** The workflow sets `PRODUCTION_CONFIG` env var based on first dropdown. Inside `_test_overrides.params`:

```bash
PRODUCTION_CONFIG="${PRODUCTION_CONFIG:-harper_deb13.params}"
```

If `PRODUCTION_CONFIG` env var is not set, it defaults to `harper_deb13.params`.

## See Also

- [params/README.md](../params/README.md) - Params file reference
- [TESTING_PARAMS_WORKFLOW.md](TESTING_PARAMS_WORKFLOW.md) - Testing patterns
- [.github/workflows/kernel-factory.yml](../.github/workflows/kernel-factory.yml) - Workflow source


### Dropdown 1: Base Configuration
Select which params file to use as the foundation:
- `tinyconfig.params` - Fast minimal build (2-5 min)
- `harper_deb13.params` - Full desktop kernel Debian 13 build (experimental)
- `foundry.params` - Template (requires customization)

### Dropdown 2: Apply Override
Choose whether to apply testing overrides:
- `none` - Use the base params directly (no changes)
- `testing.params (test output dir + enforced QA)` - Apply testing overrides

## How It Works

### Workflow UI

When you trigger a manual workflow in GitHub Actions, you'll see:

```
┌─────────────────────────────────────────────┐
│ Run workflow                                │
├─────────────────────────────────────────────┤
│ Use workflow from: Branch: alpha-rc1       │
│                                             │
│ Base Configuration ▼                        │
│ ┌─────────────────────────────────────┐    │
│ │ tinyconfig.params                   │    │
│ │ harper_deb13.params                 │    │
│ │ foundry.params                      │    │
│ └─────────────────────────────────────┘    │
│                                             │
│ Apply Override ▼                            │
│ ┌─────────────────────────────────────┐    │
│ │ none                                │    │
│ │ testing.params (test output + QA)   │    │
│ └─────────────────────────────────────┘    │
│                                             │
│                    [Run workflow]           │
└─────────────────────────────────────────────┘
```

### Execution Logic

#### Option 1: Direct Execution (Override = "none")

```
Base: harper_deb13.params
Override: none

→ Executes: params/harper_deb13.params
→ Output: /path/to/output/release/harper-deb13/
→ QA Mode: RELAXED (from original params)
```

**Use case:** Run production build exactly as configured

#### Option 2: Override Mode (Override = "testing.params...")

```
Base: harper_deb13.params
Override: testing.params (test output dir + enforced QA)

→ Sets: PRODUCTION_CONFIG=harper_deb13.params
→ Executes: params/_test_overrides.params
→ _test_overrides.params sources harper_deb13.params
→ _test_overrides.params overrides:
  • Output: /path/to/output/testing
   • QA Mode: ENFORCED
   • Bypass QA: false
```

**Use case:** Test production config with preprod output location

## Common Workflows

### 1. Fast Validation (2-5 minutes)

```
Base Configuration: tinyconfig.params
Apply Override: none
```

**Result:** Minimal kernel build for quick testing
- Uses kernel.org LTS source
- Tinyconfig base (minimal features)
- Fast build time
- Perfect for CI/PR validation

### 2. Production Preview

```
Base Configuration: harper_deb13.params
Apply Override: testing.params (test output dir + enforced QA)
```

**Result:** Full production build → preprod location
- All production settings (x86-64-v3, 1000Hz)
- Debian Trixie Backports source
- Output to `/testing` directory (not `/release`)
- ENFORCED QA mode (stricter than production)
- Perfect for pre-release testing

### 3. Full Production Build

```
Base Configuration: harper_deb13.params
Apply Override: none
```

**Result:** Exact production build
- All production settings
- Output to production directory
- RELAXED QA mode (warnings don't fail)
- Use for actual releases

### 4. Custom Testing Variations

```yaml
# Try different kernel sources with testing overrides
Base: harper_deb13.params → Override: testing.params
  → Debian Trixie source + test output

Base: tinyconfig.params → Override: testing.params
  → kernel.org LTS + test output + enforced QA
```

## Technical Flow

### Workflow Job Execution

```yaml
jobs:
  preheat:
    steps:
      - name: Configure Arguments
        run: |
          if [[ "$OVERRIDE_MODE" == "testing.params"* ]]; then
            FILE="params/_test_overrides.params"
            ENV_VARS="PRODUCTION_CONFIG=$BASE_PARAMS"
            # Passes to downstream jobs
          else
            FILE="params/$BASE_PARAMS"
            ENV_VARS=""
          fi
```

### Environment Variable Propagation

```yaml
preheat:
  outputs:
    args: --params-file params/_test_overrides.params
    env_vars: PRODUCTION_CONFIG=harper_deb13.params

smelt:
  needs: preheat
  steps:
    - name: Ignition
      env:
        PRODUCTION_CONFIG: harper_deb13.params  # From preheat
      run: |
        PRODUCTION_CONFIG=harper_deb13.params \
          bash ./scripts/furnace_ignite.sh --params-file params/_test_overrides.params
```

### Inside _test_overrides.params

```bash
#!/bin/bash
# ⚠️  REQUIRED: PRODUCTION_CONFIG environment variable must be set
# _test_overrides.params will error if PRODUCTION_CONFIG is not provided
if [ -z "$PRODUCTION_CONFIG" ]; then
    echo "❌ Error: PRODUCTION_CONFIG environment variable not set"
    exit 1
fi

# Source the specified production base config
source "$(dirname "${BASH_SOURCE[0]}")/$PRODUCTION_CONFIG"

# Apply overrides
HOST_OUTPUT_DIR="/path/to/output/testing"
QA_MODE="ENFORCED"
```

## Automatic Triggers (No Dropdowns)

When code is pushed (not manual dispatch), the workflow auto-selects configs:

| Trigger | Configuration Used |
|---------|-------------------|
| Push to `main` | `params/_test_overrides.params` (full test build) |
| Push to `dev` | `params/tinyconfig.params` (fast validation) |
| Push to `feature/*` | `params/tinyconfig.params` (fast validation) |
| Tag `v*` on `main` | `params/foundry.params` (production release) |

## Benefits

### For Testing
✅ Test production config without modifying it  
✅ Separate output directories (preprod vs production)  
✅ Stricter QA for testing builds  
✅ Same kernel settings, different delivery location  

### For CI/CD
✅ Matrix testing with different bases  
✅ Environment-specific builds (staging, preprod, test)  
✅ Version pinning for reproducible tests  
✅ Fast feedback with tinyconfig, thorough testing with full config  

### For Maintenance
✅ Single source of truth for production settings  
✅ Easy to add new override profiles  
✅ No duplicate configuration files  
✅ Clear separation between kernel config and build parameters  

## Advanced: Creating Additional Override Profiles

You can create multiple override profiles:

```bash
# params/_staging.params
source "$(dirname "${BASH_SOURCE[0]}")/${PRODUCTION_CONFIG:-harper_deb13.params}"
HOST_OUTPUT_DIR="/path/to/output/staging"
QA_MODE="RELAXED"
KERNEL_VERSION="6.12.8"  # Pinned for stability

# params/_preprod.params
source "$(dirname "${BASH_SOURCE[0]}")/${PRODUCTION_CONFIG:-harper_deb13.params}"
HOST_OUTPUT_DIR="/path/to/output/preprod"
QA_MODE="ENFORCED"
ENABLE_QEMU_TESTS="true"
```

Then add to workflow:

```yaml
override_mode:
  description: 'Apply Override'
  options:
    - 'none'
    - 'testing.params (test output + enforced QA)'
    - 'staging.params (stable version + relaxed QA)'
    - 'preprod.params (full QEMU testing)'
```

## Troubleshooting

### Error: PRODUCTION_CONFIG environment variable not set

**Problem:** When running `_test_overrides.params`, you get:
```
❌ Error: PRODUCTION_CONFIG environment variable not set
This params file requires a production base config to be specified.
```

**Solution:** `_test_overrides.params` is an override file that requires a base config. You must specify which production params to use:

```bash
# Correct usage
PRODUCTION_CONFIG=harper_deb13.params ./start_build.sh -p params/_test_overrides.params

# Wrong usage (will error)
./start_build.sh -p params/_test_overrides.params
```

**Why:** This ensures explicit config selection in GitHub workflows and prevents accidental use of undefined defaults.

### Override not applied

**Problem:** Selected "testing.params" override but build used base params directly

**Check:**
1. Verify workflow logs show: `🧪 Applying testing overrides to...`
2. Check `env_vars` output contains `PRODUCTION_CONFIG=...`
3. Ensure `_test_overrides.params` correctly sources `$PRODUCTION_CONFIG`

### Wrong base params sourced

**Problem:** Testing override using wrong base configuration

**Solution:** The workflow sets `PRODUCTION_CONFIG` env var based on first dropdown. Inside `_test_overrides.params`:

```bash
PRODUCTION_CONFIG="${PRODUCTION_CONFIG:-harper_deb13.params}"
```

If `PRODUCTION_CONFIG` env var is not set, it defaults to `harper_deb13.params`.

## See Also

- [params/README.md](../params/README.md) - Params file reference
- [TESTING_PARAMS_WORKFLOW.md](TESTING_PARAMS_WORKFLOW.md) - Testing patterns
- [.github/workflows/kernel-factory.yml](../.github/workflows/kernel-factory.yml) - Workflow source
