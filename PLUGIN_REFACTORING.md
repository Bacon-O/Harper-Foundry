# Plugin Refactoring Summary

**Date**: February 14, 2026  
**Branch**: alpha-rc1

## Overview

Refactored the Harper Foundry plugin system to improve modularity and organization:
1. Extracted BORE patch logic into a dedicated plugin
2. Reorganized QA tests into logical subdirectories

## Changes Made

### 1. BORE Patch Plugin

**Created**: `scripts/plugins/patches/bore.sh`
- Modular plugin for applying BORE scheduler patches
- Exports `SCHEDULER_LABEL` and `SCHED_PRIORITY` variables
- Automatic fallback to EEVDF on patch failure
- Clean separation of concerns

**Created**: `scripts/plugins/patches/README.md`
- Comprehensive documentation for patch plugins
- Template for creating new patch plugins
- Usage examples and best practices

**Modified**: `scripts/alloymixtures/harper_alloy_deb13.sh`
- Removed inline BORE patching code (lines 36-46)
- Now sources the BORE plugin: `source "${PLUGIN_DIR}/patches/bore.sh"`
- Simplified versioning logic (removed redundant scheduler check)

### 2. QA Test Reorganization

**Directory Structure**:
```
scripts/plugins/qatests/
├── tests/              # NEW: Individual test scripts
│   ├── debpackage.sh   # MOVED from qatests/
│   ├── filesexists.sh  # MOVED from qatests/
│   ├── linuxconfig.sh  # MOVED from qatests/
│   └── qemuboot.sh     # MOVED from qatests/
└── packages/           # RENAMED from testpackages/
    └── harperbase/
        ├── .testlist
        └── linuxconfig.sh
```

**Created**: `scripts/plugins/qatests/README.md`
- Complete QA test framework documentation
- Explains test types, usage, and configuration
- Templates for creating new tests and packages

**Modified**: `params/foundry.params`
- Updated `TEST_FUNCTIONS_DIR="$PLUGIN_DIR/qatests/tests/"`
- Updated `TEST_PACKAGE_DIR="$PLUGIN_DIR/qatests/packages/"`

**Modified**: `params/tinyconfig.foundry.params`
- Updated `TEST_FUNCTIONS_DIR="$PLUGIN_DIR/qatests/tests/"`
- Updated `TEST_PACKAGE_DIR="$PLUGIN_DIR/qatests/packages/"`

**Modified**: `scripts/validate_params.sh`
- Updated test path validation to `qatests/tests/`
- Updated package path validation to `qatests/packages/`

### 3. Documentation Updates

**Modified**: `README.md`
- Updated QA section with new directory structure
- Added Plugin System section under Advanced Usage
- Documented BORE scheduler plugin
- Added links to plugin documentation

## Benefits

### Modularity
- BORE patching is now a self-contained, reusable plugin
- Easy to add new patch plugins (RT-patch, custom patches, etc.)
- Clear separation between patch logic and build logic

### Organization
- QA tests are logically grouped
- Individual tests separated from test packages
- Consistent naming (tests/ and packages/)

### Maintainability
- Comprehensive README files for each plugin type
- Templates for creating new plugins
- Better code reusability

### Extensibility
- Plugin architecture makes it easy to add:
  - New kernel patches (RT, custom schedulers, etc.)
  - New QA test categories
  - Custom build steps

## Migration Notes

### No Breaking Changes
All existing functionality preserved:
- ✅ Both params files validate successfully
- ✅ QA test execution unchanged
- ✅ BORE patching behavior identical
- ✅ All path references updated

### File Moves
- `scripts/plugins/qatests/*.sh` → `scripts/plugins/qatests/tests/*.sh`
- `scripts/plugins/qatests/testpackages/` → `scripts/plugins/qatests/packages/`

### New Files
- `scripts/plugins/patches/bore.sh` (executable)
- `scripts/plugins/patches/README.md`
- `scripts/plugins/qatests/README.md`

## Testing

Validated with:
```bash
./scripts/validate_params.sh params/foundry.params
./scripts/validate_params.sh params/tinyconfig.foundry.params
```

Both configurations pass all validation checks:
- ✅ All paths resolved correctly
- ✅ QA tests found and executable
- ✅ Test packages located
- ✅ No errors or warnings

## Next Steps

Consider adding additional patch plugins:
- **RT-PREEMPT**: Real-time kernel patches
- **Custom Schedulers**: Other scheduler implementations
- **Security Patches**: CVE fixes, hardening patches
- **Feature Patches**: Experimental kernel features

## References

- [BORE Scheduler](https://github.com/firelzrd/bore-scheduler)
- [Patches Plugin Docs](scripts/plugins/patches/README.md)
- [QA Tests Docs](scripts/plugins/qatests/README.md)
- [Alloy Mixtures Docs](scripts/alloymixtures/README.md)
