# Custom Tools

Add custom utility scripts and helpers here.

## Purpose

Extend Harper Foundry with:
- Build profiling tools
- Log analysis utilities
- Custom setup scripts
- Helper functions
- Monitoring tools
- Debugging utilities

## Examples

### QEMU Setup

```bash
#!/bin/bash
# scripts/scripts.d/plugins/tools/custom_qemu_setup.sh

setup_custom_qemu() {
    echo "Setting up custom QEMU..."
    # Your QEMU setup logic
}
```

### Build Profiler

```bash
#!/bin/bash
# scripts/scripts.d/plugins/tools/build_profiler.sh

profile_build() {
    echo "Profiling build..."
    time make -j"$FINAL_JOBS"
    # Additional profiling
}
```

### Log Analyzer

```bash
#!/bin/bash
# scripts/scripts.d/plugins/tools/log_analyzer.sh

analyze_build_log() {
    echo "Analyzing build log..."
    grep -i "warning\|error" build.log | head -50
}
```

### Resource Monitor

```bash
#!/bin/bash
# scripts/scripts.d/plugins/tools/resource_monitor.sh

monitor_resources() {
    echo "Monitoring build resources..."
    watch -n 1 'free -h && df -h'
}
```

## Usage

### Direct Execution

```bash
source scripts/scripts.d/plugins/tools/mytool.sh
mytool_function
```

### From Build Scripts

```bash
if [[-f scripts/scripts.d/plugins/tools/mytool.sh ]]; then
    source scripts/scripts.d/plugins/tools/mytool.sh
    mytool_setup
fi
```

## Smart Lookup

Custom tools are checked in `scripts/scripts.d/plugins/tools/` before official tools in `scripts/plugins/tools/`.

## See Also

- [Official tools documentation](../../plugins/tools/README.md)
- [Custom scripts documentation](../README.md)
