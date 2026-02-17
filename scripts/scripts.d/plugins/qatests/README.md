# Custom QA Tests

Add custom quality assurance tests here. These run alongside official QA tests.

## Purpose

Validate build artifacts and functionality:
- Custom benchmarks
- Memory tests
- Compatibility checks
- Custom hardware validation
- Application-specific testing

## Directory Structure

```bash
scripts/scripts.d/plugins/qatests/
├── packages/           # QA test packages (reusable)
│   └── mytest/
│       ├── runner.sh
│       └── mytest.sh
├── tests/              # Standalone test scripts
│   ├── memtest.sh
│   └── custom_bench.sh
└── README.md
```

## Standalone Tests

Simple test scripts in `tests/`:

```bash
#!/bin/bash
# scripts/scripts.d/plugins/qatests/tests/memtest.sh

echo "Testing memory..."
# Your test logic
```

## QA Test Packages

Complex tests package with `runner.sh` in `packages/`:

```bash
scripts/scripts.d/plugins/qatests/packages/mytest/
├── runner.sh       # Entry point called by QA system
└── mytest.sh       # Test implementation
```

### runner.sh Template

```bash
#!/bin/bash
# scripts/scripts.d/plugins/qatests/packages/mytest/runner.sh

. "$(dirname "$0")/mytest.sh"

run_test() {
    echo "Running custom test..."
    # Call your test functions
}

run_test
```

### Test Script Template

```bash
#!/bin/bash
# scripts/scripts.d/plugins/qatests/packages/mytest/mytest.sh

test_memory() {
    echo "Testing memory..."
    # Test logic
}

test_cpu() {
    echo "Testing CPU..."
    # Test logic
}
```

## Usage

### Standalone Tests

Automatically discovered and run for files in `tests/`.

### Packaged Tests

Reference in params:

```bash
# params/your.params
QA_TESTS=("mytest")
```

## Examples

### Memory Benchmark

```bash
#!/bin/bash
# scripts/scripts.d/plugins/qatests/tests/lmbench.sh

echo "Running LMBench memory benchmark..."
lmbench_simple
echo "Benchmark complete"
```

### Custom Driver Validation

```bash
#!/bin/bash
# scripts/scripts.d/plugins/qatests/packages/custom_driver/runner.sh

. "$(dirname "$0")/driver_test.sh"

validate_driver
test_driver_functionality
```

## Smart Lookup

QA tests from `scripts/scripts.d/plugins/qatests/` run before official tests in `scripts/plugins/qatests/`.

## Exit Codes

Return appropriate exit codes:
- `0` - Test passed
- `1` - Test failed
- `2` - Test skipped/not applicable

## See Also

- [Official QA tests documentation](../../plugins/qatests/README.md)
- [Custom scripts documentation](../README.md)
