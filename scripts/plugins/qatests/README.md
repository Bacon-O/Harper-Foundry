# QA Tests Plugin System

This directory contains the Quality Assurance (QA) test framework for the Harper Foundry.

## Directory Structure

```
qatests/
├── tests/          # Individual QA test scripts
│   ├── debpackage.sh
│   ├── filesexists.sh
│   ├── linuxconfig.sh
│   └── qemuboot.sh
└── packages/       # QA test package bundles
    └── harperbase/ # Base test package
        ├── .testlist
        └── linuxconfig.sh
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

Bundled test suites that group related tests together:

- **`harperbase/`**: Base test package for Harper builds
  - Contains `.testlist` file specifying which tests to run
  - May include package-specific test scripts

Test packages are referenced in the `QA_TEST_PACKAGE` array in params files.

## Usage

Tests are automatically executed by `scripts/material_analysis.sh` after the build completes.

### Configuration

In your params file:

```bash
# QA Configuration
QA_MODE="SOFT"                                    # HARD = fail build | SOFT = warn only
BYPASS_QA="false"                                  # Set true to skip all QA
TEST_FUNCTIONS_DIR="$PLUGIN_DIR/qatests/tests/"   # Individual tests location
TEST_PACKAGE_DIR="$PLUGIN_DIR/qatests/packages/"  # Test packages location

# Individual tests to run
QA_TESTS=(
    "filesexists.sh"
    "linuxconfig.sh"
)

# Test packages to run
QA_TEST_PACKAGE=(
    "harperbase"
)
```

### QA Modes

- **`SOFT`**: Tests run but failures only generate warnings (default)
- **`HARD`**: Test failures abort the build immediately

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

1. Create executable bash script in `tests/`
2. Add to `QA_TESTS` array in params file
3. Use standard test functions:
   ```bash
   #!/bin/bash
   set -e
   
   # Your test logic here
   if [ ! -f "expected-file.deb" ]; then
       echo "❌ Test failed: File not found"
       exit 1
   fi
   
   echo "✅ Test passed"
   exit 0
   ```

### Test Package

1. Create directory in `packages/`
2. Add `.testlist` file listing tests to run:
   ```
   filesexists.sh
   linuxconfig.sh
   debpackage.sh
   ```
3. Optionally add package-specific test scripts
4. Add package name to `QA_TEST_PACKAGE` array

## Test Execution Order

1. **Phase 1**: Individual tests (from `QA_TESTS` array)
2. **Phase 2**: Package bundles (from `QA_TEST_PACKAGE` array)

All tests run on the host system after the Docker build completes.
