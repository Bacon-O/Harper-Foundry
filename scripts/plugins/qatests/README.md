# QA Tests Plugin System

This directory contains the Quality Assurance (QA) test framework for the Harper Foundry.

## Directory Structure

```
qatests/
├── tests/           # Individual QA test scripts
│   ├── debpackage.sh
│   ├── filesexists.sh
│   ├── linuxconfig.sh
│   └── qemuboot.sh
├── packages/        # Official test package definitions
│   ├── harperbase/
│   └── README.md

scripts.d/plugins/qatests/      # Your custom tests (gitignored)
├── tests/           # Your custom test scripts
└── packages/        # Your custom test package definitions
    └── mytest/
```

## Test Types

### Individual Tests (`tests/`)

Standalone test scripts that validate specific aspects of the build:

- **`debpackage.sh`**: Validates Debian package integrity
- **`filesexists.sh`**: Checks that required build artifacts exist
- **`linuxconfig.sh`**: Validates kernel configuration options
- **`qemuboot.sh`**: Tests kernel boot in QEMU (if enabled)

Individual tests are referenced in the `QA_TESTS` array in params files.

### Test Packages (`packages/`)

Bundled test suites defined as `.lst` files that reference tests from `tests/`:

- **`harper.lst`**: Full test package for Harper builds
  - Lists test names to run from `TEST_FUNCTIONS_DIR`
  - One test per line
  - Supports comments (lines starting with `#`)
  - No symlinks required

Test packages are referenced in the `QA_TEST_PACKAGE` array in params files.

## Usage

Tests are automatically executed by `scripts/material_analysis.sh` after the build completes.

### Configuration

In your params file:

```bash
# QA Configuration
QA_MODE="RELAXED"                              # ENFORCED = fail build | RELAXED = warn only
BYPASS_QA="false"                                  # Set true to skip all QA
# Note: TEST_FUNCTIONS_DIR and TEST_PACKAGE_DIR are automatically set by env_setup.sh
# They default to the plugin directories but can be overridden if needed

# Individual tests to run
QA_TESTS=(
    "filesexists.sh"
    "linuxconfig.sh"
)

# Test packages to run (references .lst files in packages/)
QA_TEST_PACKAGE=(
    "harper"
)
```

### QA Modes

- **`RELAXED`**: Tests run but failures only generate warnings (default)
- **`ENFORCED`**: Test failures abort the build immediately

### Bypass QA

To skip QA entirely:
```bash
./start_build.sh --bypass-qa
```

Or set in params:
```bash
BYPASS_QA="true"
```

## Creating New Tests

### Individual Test Script

**Smart Lookup**: The system automatically searches for custom tests without requiring explicit paths!

1. Create executable bash script in **either**:
   - `scripts/plugins/qatests/tests/` (project tests)
   - `scripts/scripts.d/plugins/qatests/tests/` (custom tests - **recommended for users**)

2. Add to `QA_TESTS` array in params file using **just the filename**:
   ```bash
   QA_TESTS=(
       "custom_example.sh"     # System finds it automatically!
       "filesexists.sh"        # Can mix custom and project tests
   )
   ```

3. Use standard test functions:
   ```bash
   #!/bin/bash
   set -e
   
   # Your test logic here
   if [[ ! -f "expected-file.deb" ]]; then
       echo "❌ Test failed: File not found"
       exit 1
   fi
   
   echo "✅ Test passed"
   exit 0
   ```

**Path Lookup Order** (transparent to user):
1. Check `scripts/scripts.d/plugins/qatests/` (custom - takes precedence)
2. Fall back to `scripts/plugins/qatests/tests/` (project)

### Test Package

**Smart Lookup**: The system automatically finds test packages with just the name!

1. Create a `.lst` file in **either**:
   - `scripts/plugins/qatests/packages/` (project packages)
   - `scripts/scripts.d/plugins/qatests/packages/` (custom packages - **recommended for users**)

2. List test names to run, one per line:
   ```
   # Full test suite
   filesexists.sh
   linuxconfig.sh
   debpackage.sh
   qemuboot.sh
   ```
   - Each line references a test script from `TEST_FUNCTIONS_DIR`
   - Tests are resolved and executed automatically
   - Lines starting with `#` are treated as comments
   - Empty lines are ignored

3. Add package name (without `.lst`) to `QA_TEST_PACKAGE` array in params file using **just the name**:
   ```bash
   QA_TEST_PACKAGE=(
       "custom"       # System finds custom.lst automatically!
       "harper"       # Can mix custom and project packages
   )
   ```

**Path Lookup Order** (transparent to user):
1. Check `scripts/scripts.d/plugins/qatests/` (custom - takes precedence)
2. Fall back to `scripts/plugins/qatests/packages/` (project)

**Benefits of using `scripts/scripts.d/plugins/qatests/`:**
- ✅ No git conflicts during updates
- ✅ Keeps custom tests separate from project
- ✅ Easy to maintain multiple test profiles
- ✅ Safe to do `git pull`
- ✅ **No need to know the full path** - just use the filename!

## Contributing Tests to Harper Foundry

For tests you want to contribute back:

1. Create `.sh` script in `qatests/tests/` or `.lst` file in `packages/`

## Test Execution Order

1. **Phase 1**: Individual tests (from `QA_TESTS` array)
2. **Phase 2**: Package bundles (from `QA_TEST_PACKAGE` array)

All tests run on the host system after the Docker build completes.

## Design Notes

Test packages use simple `.lst` files instead of directories. This design choice:

- **Reduces complexity**: One file instead of a directory tree
- **Eliminates duplication**: No symlinks or file copying needed
- **Improves maintainability**: Clear separation between test definitions and implementations
- **Enables flexibility**: Easy to create new test bundles without directory management
