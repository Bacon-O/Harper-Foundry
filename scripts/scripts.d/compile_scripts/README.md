# Custom Compile Scripts

Add your own compile script variants here. These will override official compile scripts with the same name.

## Examples

Create variants for your specific use cases:

- `minimal.sh` - Embedded/IoT kernel with minimal features
- `debug.sh` - Build with debug symbols and verbose logging
- `hardened.sh` - Security-focused hardened kernel
- `performance.sh` - Optimized for benchmarking
- `rt.sh` - Real-time preemption kernel (PREEMPT_RT)

## Template

```bash
#!/bin/bash
# scripts/scripts.d/compile_scripts/myconfig.sh
# Custom compile script for Harper Foundry

# Copy from official script and customize
set -e

echo "🔧 Starting custom build (myconfig.sh)..."

# Your build logic here
# Access official build functions and variables

echo "✅ Custom build complete"
```

## Usage

```bash
./start_build.sh --exec myconfig.sh
```

## Smart Lookup

When you use `--exec myconfig.sh`:
1. Looks in `scripts/scripts.d/compile_scripts/myconfig.sh` first
2. Falls back to `scripts/compile_scripts/myconfig.sh` if custom not found

This means your custom scripts **override** official ones with the same name.

## See Also

- [Official compile scripts](../../compile_scripts/README.md)
- [Custom scripts documentation](../README.md)
