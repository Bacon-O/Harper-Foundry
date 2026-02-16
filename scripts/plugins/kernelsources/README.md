# Kernel Source Plugins

This directory contains the kernel source fetching plugin system. It allows flexible, parameterized kernel source handling for different kernel sources.

## Overview

Instead of hardcoding kernel source logic in build scripts, the plugin system maps the `KERNEL_SOURCE` parameter to specific source-fetching implementations:

- **kernel.org**: Official vanilla upstream sources (ideal for tinyconfig)
- **debian**: Debian apt-get source with patches (ideal for Harper/Debian tweaks)
- **debian/trixie-backports**: Debian Trixie Backports (newer kernels with Debian integration)
- **custom** or **none**: Skip automatic fetch; implement custom logic in your ci-build script

## Version Alias System

Instead of always specifying exact versions (e.g., "6.11.8"), you can use semantic aliases that each plugin interprets intelligently:

| Alias | Meaning | kernel.org | debian | trixie-backports |
|-------|---------|-----------|--------|------------------|
| `""` (empty) | Default for source | 6.11.8 stable | Latest available | Latest available |
| `latest` | Latest available | 6.11.8 stable | Latest available | Latest available |
| `stable` | Latest stable | 6.11.8 | Latest stable | Latest stable |
| `lts` | Latest LTS version | 6.1.112 | LTS if found | LTS if found |
| `rc` | Release candidate | Latest RC | RCs if available | RCs if available |
| `6.11.8` | Specific version | 6.11.8 exact | 6.11.8 exact | 6.11.8 exact |

### Why Version Aliases?

This approach keeps your configs **forward-compatible** and **semantic**:
- Your tinyconfig build always gets the latest stable kernel.org release (no manual updates needed)
- Harper builds always get the newest kernel from trixie-backports (cutting-edge feature access)
- You can pin to "lts" to stay on stable LTS kernels
- You can request "rc" to test release candidates

## Usage

### In Build Scripts (e.g., tinyconfig.sh)

```bash
#!/bin/bash

# Load environment and kernel source plugin system
source /opt/factory/scripts/plugins/kernelsources/runner.sh

# Fetch kernel source based on KERNEL_SOURCE parameter
# KERNEL_VERSION is optional - can be empty, "latest", or a specific version
KERNEL_DIR=$(fetch_kernel_source "$KERNEL_SOURCE" "$KERNEL_VERSION")
if [ $? -ne 0 ]; then
    echo "Failed to fetch kernel"
    exit 1
fi

# Build kernel
cd "$KERNEL_DIR"
make tinyconfig
make -j$(nproc) bzImage
```

### In Parameter Files (e.g., foundry.params)

```bash
# Choose kernel source strategy
KERNEL_SOURCE="kernel.org"              # or "debian", "debian/trixie-backports"

# Kernel version (optional - defaults shown below)
# Leave empty to use defaults, set to "latest" for newest available
# or specify exact version like "6.11.8"
KERNEL_VERSION=""                       # Uses default (6.11.8 for kernel.org)
# KERNEL_VERSION="latest"               # Fetches latest available
# KERNEL_VERSION="6.11.8"               # Pins to exact version

# Base kernel config (used by make target)
BASE_CONFIG="tinyconfig"
```

### Custom Implementation

If you need custom kernel source logic:

1. Set `KERNEL_SOURCE="custom"` in your params file
2. The plugin runner will skip automatic fetch
3. Implement your own fetching logic in your ci-build script:

```bash
#!/bin/bash

source /opt/factory/scripts/plugins/kernelsources/runner.sh

if [ "$KERNEL_SOURCE" == "custom" ]; then
    # Your custom logic here
    git clone https://my-kernel-repo.com/kernel.git $BUILD_ROOT/kernel
    cd $BUILD_ROOT/kernel
    git checkout stable-6.11
elif [ "$KERNEL_SOURCE" == "internal-mirror" ]; then
    # Or handle other custom types
    rsync -av kernel-mirror.internal:/kernels/ $BUILD_ROOT/
fi

make tinyconfig
make -j$(nproc) bzImage
```

## Available Plugins

### kernel_org.sh

**Use case**: Official vanilla upstream kernels, minimal builds, tinyconfig

- Downloads from: `https://cdn.kernel.org/pub/linux/kernel/vX.x/`
- No Debian patches applied
- Caches downloaded tarballs for faster rebuilds
- Best for: Quick test builds, minimal configurations
- **Default version**: 6.11.8

**KERNEL_VERSION behavior**:
- Empty or omitted: 6.11.8 (latest stable)
- "latest": 6.11.8 (latest stable)
- "stable": 6.11.8 (latest stable)
- "lts": 6.1.112 (latest LTS kernel)
- "rc": latest release candidate
- Specific version: "6.11.8", "6.10.5", etc. (exact version)

**Examples**:
```bash
KERNEL_SOURCE="kernel.org"
# KERNEL_VERSION=""                     # Defaults to 6.11.8 stable
# KERNEL_VERSION="latest"               # Gets 6.11.8 stable
# KERNEL_VERSION="lts"                  # Gets 6.1.x LTS kernel
# KERNEL_VERSION="6.10.5"               # Pins to specific version
```

### debian.sh

**Use case**: Debian kernel with Debian patches applied

- Uses: `apt-get source linux-image=<version>` or `apt-get source linux-image` for latest
- Includes Debian customizations and patches
- Requires: deb-src lines in /etc/apt/sources.list
- Best for: Full builds with standard Debian tweaks

**KERNEL_VERSION behavior**:
- Empty or omitted: Latest available in Debian repos (no version constraint)
- "latest": Latest available (same as empty)
- "stable": Latest stable
- "lts": LTS kernels if available in Debian
- "rc": Release candidates if available
- Specific version: "6.11.8", "6.10.5", etc. (exact version if available)

**Examples**:
```bash
KERNEL_SOURCE="debian"
# KERNEL_VERSION=""                     # Fetches latest available
# KERNEL_VERSION="latest"               # Same as empty
# KERNEL_VERSION="lts"                  # Get LTS kernel if available
# KERNEL_VERSION="6.11.8"               # Pin to specific version
```

**Requirements**:
```bash
# Ensure deb-src is enabled
echo "deb-src http://deb.debian.org/debian $(lsb_release -cs) main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
```

### trixie_backports.sh

**Use case**: Newer kernels from Debian Trixie Backports with Debian patches

- Uses: `apt-get source -t trixie-backports linux-image=<version>` or without version constraint for latest
- Includes Trixie-patched kernels (newer than stable Debian)
- Requires: deb-src for trixie-backports in /etc/apt/sources.list
- Best for: Harper builds needing newer kernels with full Debian integration

**KERNEL_VERSION behavior**:
- Empty or omitted: Latest available from trixie-backports (recommended for always-fresh builds)
- "latest": Latest available (same as empty)
- "stable": Latest stable from trixie-backports
- "lts": LTS kernels from trixie-backports if available
- "rc": Release candidates if available
- Specific version: "6.11.8", "6.10.5", etc. (pins to exact version if available)

**Examples**:
```bash
KERNEL_SOURCE="debian/trixie-backports"
# KERNEL_VERSION=""                     # Defaults to latest
# KERNEL_VERSION="latest"               # Always newest from trixie-backports
# KERNEL_VERSION="lts"                  # Get LTS from trixie-backports
# KERNEL_VERSION="6.11.8"               # Pin to specific version
```

**Aliases**: `debian/trixie-backports`, `trixie-backports`, `trixie`

**Setup Requirements**:
```bash
# Add trixie-backports to your sources
echo "deb http://deb.debian.org/debian trixie-backports main" | sudo tee -a /etc/apt/sources.list
echo "deb-src http://deb.debian.org/debian trixie-backports main" | sudo tee -a /etc/apt/sources.list

# Update package list
sudo apt-get update
```

**Why this matters**:
- Trixie is Debian's testing/unstable branch with newer packages
- Backports provides those newer kernels for stable Debian systems
- Includes all Debian's kernel patches and customizations
- Better for projects like Harper that need recent kernel features
- Setting `KERNEL_VERSION="latest"` ensures always building with newest kernel

## Plugin API

### fetch_kernel_source()

Central function that routes to appropriate plugin.

**Signature**:
```bash
fetch_kernel_source <source_type> [kernel_version] [build_root]
```

**Arguments**:
- `source_type`: One of kernel.org, debian, debian/trixie-backports, custom, none (case-insensitive)
- `kernel_version`: Optional. Can be:
  - Empty string or omitted: Uses plugin defaults
  - "latest": Fetches latest available from source
  - Specific version: "6.11.8", "6.10.5", etc.
- `build_root`: Where to download/extract (optional, defaults to current dir)

**Returns**:
- Prints kernel directory path to stdout
- Exits with code 0 on success, non-zero on failure

**Examples**:
```bash
# Use defaults (kernel.org with 6.11.8)
KERNEL_DIR=$(fetch_kernel_source "kernel.org")

# Always get latest from trixie-backports
KERNEL_DIR=$(fetch_kernel_source "debian/trixie-backports" "latest")

# Pin to specific version
KERNEL_DIR=$(fetch_kernel_source "kernel.org" "6.10.5")

# Use latest from any source
KERNEL_DIR=$(fetch_kernel_source "debian" "" "/tmp/build")
```

## Adding New Plugins

To create a new kernel source plugin:

1. Create `plugins/kernelsources/mysource.sh`
2. Implement the plugin to:
   - Accept `$1` = kernel_version, `$2` = build_root
   - Create/extract kernel source
   - Print path to kernel directory to stdout
   - Exit with 0 on success, non-zero on failure
3. Add case statement to `runner.sh` with your source type
4. Document usage in this README

**Minimal plugin template**:
```bash
#!/bin/bash
set -e

KERNEL_VERSION="${1:-6.11.8}"
BUILD_ROOT="${2:-.}"

mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

# Download/extract kernel source here
# ...

echo "[INFO] Kernel source ready: $BUILD_ROOT/kernel-dir" >&2
echo "$BUILD_ROOT/kernel-dir"
```

## Adding to Tinyconfig Build

See [scripts/alloymixtures/README.md](../alloymixtures/README.md) for how tinyconfig.sh integrates the kernel source plugin system.

## Troubleshooting

### "Unknown KERNEL_SOURCE type"
Check your params file - KERNEL_SOURCE must be one of: kernel.org, debian, custom, none

### "Plugin not found or not executable"
Run: `chmod +x /path/to/plugin.sh`

### "Failed to download from kernel.org"
- Check internet connectivity
- Verify kernel version exists: https://www.kernel.org/releases.html
- Try manual download: `wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.11.8.tar.xz`

### "Failed to fetch Debian kernel source"
- Ensure deb-src lines are in /etc/apt/sources.list
- Run: `sudo apt-get update`
- Check that kernel version is available in your Debian release
