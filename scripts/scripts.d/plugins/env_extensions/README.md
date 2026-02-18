# Custom Environment Extensions

This directory is for your custom environment extension scripts.

## Overview

Environment extensions allow you to inject custom environment variables and setup logic into the container before the build runs.

## Usage

1. Create your custom extension script in this directory:
   ```bash
   cp ../../../plugins/env_extensions/EXAMPLE-container_optimized.sh custom_env.sh
   # Edit custom_env.sh as needed
   ```

2. Reference it in your params file:
   ```bash
   ENV_EXTENSIONS_CUSTOM="custom_env.sh"
   ```

## How It Works

The system automatically checks `scripts.d/plugins/env_extensions/` first for custom extensions, then falls back to `scripts/plugins/env_extensions/` for official extensions.

This allows you to override or extend the container setup without modifying official files.

## Example Structure

```bash
# Official (read-only)
scripts/plugins/env_extensions/
├── EXAMPLE-container_optimized.sh
└── README.md

# Your Custom (gitignored)
scripts/scripts.d/plugins/env_extensions/
├── my_custom_env.sh
└── optimizations.sh
```

## Documentation

See `scripts/plugins/env_extensions/README.md` for detailed information about creating environment extensions.
