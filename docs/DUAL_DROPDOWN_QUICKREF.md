## Dual Dropdown Quick Reference

### Workflow UI Dropdowns

```
┌─────────────────────────────────────────┐
│ Dropdown 1: Base Configuration         │
├─────────────────────────────────────────┤
│ • tinyconfig.params                     │
│ • harper_alloy_deb13.params             │
│ • foundry.params                        │
│ • _example.params                       │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Dropdown 2: Apply Override              │
├─────────────────────────────────────────┤
│ • none                                  │
│ • testing.params (test dir + QA)        │
└─────────────────────────────────────────┘
```

### Common Combinations

| Base Config | Override | Result | Use Case |
|------------|----------|--------|----------|
| `tinyconfig.params` | `none` | Fast minimal build (2-5 min) | Quick validation |
| `harper_alloy_deb13.params` | `none` | Full desktop kernel build | Enthusiast builds |
| `harper_alloy_deb13.params` | `testing.params` | Base config → test output | Preprod testing |
| `tinyconfig.params` | `testing.params` | Fast build → test output + enforced QA | CI testing |

### Execution Examples

**Example 1: No Override**
```
Dropdown 1: harper_alloy_deb13.params
Dropdown 2: none

Workflow executes:
  bash ./scripts/furnace_ignite.sh --params-file params/harper_alloy_deb13.params

Result:
  • Sources: params/harper_alloy_deb13.params
  • Output: /mnt/build-data/dist/release/harper-deb13/
  • QA Mode: RELAXED (from original params)
```

**Example 2: With Testing Override**
```
Dropdown 1: harper_alloy_deb13.params
Dropdown 2: testing.params (test output dir + enforced QA)

Workflow executes:
  PRODUCTION_CONFIG=harper_alloy_deb13.params \
    bash ./scripts/furnace_ignite.sh --params-file params/_test_overrides.params

Result:
  • _test_overrides.params sources: harper_alloy_deb13.params
  • Output: /mnt/build-data/dist/testing (overridden)
  • QA Mode: ENFORCED (overridden)
  • Bypass QA: false (overridden)
```

### Local Testing

Test the same logic locally:

```bash
# No override
./start_build.sh -p params/harper_alloy_deb13.params

# With testing override (PRODUCTION_CONFIG is REQUIRED)
PRODUCTION_CONFIG=harper_alloy_deb13.params \
  ./start_build.sh -p params/_test_overrides.params

# ⚠️  This will ERROR (PRODUCTION_CONFIG not set):
./start_build.sh -p params/_test_overrides.params
```

### Benefits at a Glance

✅ **Single source of truth** - One base config  
✅ **Flexible testing** - Test with different output locations  
✅ **No duplication** - Override only what differs  
✅ **Easy matrix testing** - Test multiple bases with same overrides  
✅ **Environment-specific** - Preprod, staging, testing from one config  

### Workflow Flow Diagram

```
Manual Dispatch
    │
    ├─> Select Base: harper_alloy_deb13.params
    └─> Select Override: testing.params
         │
         v
    Configure Arguments
         │
         ├─> FILE="params/_test_overrides.params"
         └─> ENV_VARS="PRODUCTION_CONFIG=harper_alloy_deb13.params"
              │
              v
    Execute Build
         │
         └─> PRODUCTION_CONFIG=harper_alloy_deb13.params \
             bash ./scripts/furnace_ignite.sh \
               --params-file params/_test_overrides.params
                  │
                  v
    Inside Container
         │
         └─> _test_overrides.params sources harper_alloy_deb13.params
         └─> Applies overrides (output dir, QA mode)
         └─> Build executes with combined config
```

### See Also

- [GITHUB_DUAL_DROPDOWN.md](GITHUB_DUAL_DROPDOWN.md) - Detailed guide
- [params/README.md](../params/README.md) - Params reference
- [TESTING_PARAMS_WORKFLOW.md](TESTING_PARAMS_WORKFLOW.md) - Testing patterns
