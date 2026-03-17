# GitHub Actions: Dual Dropdown Workflow

This document explains the **dual dropdown system** for GitHub Actions workflows that provides flexible parameter configuration with optional testing overrides.

## Quick Reference

### Workflow UI Dropdowns

```
┌─────────────────────────────────────────┐
│ Dropdown 1: Base Configuration          │
├─────────────────────────────────────────┤
│ • tinyconfig.params                     │
│ • harper_deb13.params                   │
│ • foundry_template.params               │
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


- [params/README.md](../params/README.md) - Params file reference
- [TESTING_PARAMS_WORKFLOW.md](TESTING_PARAMS_WORKFLOW.md) - Testing patterns
- [.github/workflows/kernel-factory.yml](../.github/workflows/kernel-factory.yml) - Workflow source
