# Custom Kernel Source Plugins

Add custom kernel source fetchers here. These override official kernel source plugins with the same name.

## Purpose

Replace or extend kernel source fetching with:
- Custom repositories (GitLab, internal servers)
- Alternative architectures
- Development branches
- Patched versions

## Template

```bash
#!/bin/bash
# scripts/scripts.d/plugins/kernelsources/mykernel.sh

fetch_kernel() {
    echo "Fetching custom kernel..."
    # Download kernel source
    # Set KERNEL_SOURCE_PATH variable
    # Set KERNEL_VERSION variable
}

# Export the function
export -f fetch_kernel
```

## Usage

Reference in your params file:

```bash
# params/your.params
ENV_EXTENSIONS=("kernelsources/mykernel.sh")
KERNEL_SOURCE="mykernel"
```

## Examples

### Private Repository

```bash
#!/bin/bash
# scripts/scripts.d/plugins/kernelsources/gitlab_private.sh

fetch_kernel() {
    echo "Fetching from private GitLab..."
    git clone https://private.gitlab.com/kernel.git kernel_src
    cd kernel_src
    git checkout my-branch
    KERNEL_SOURCE_PATH="$PWD"
    KERNEL_VERSION="$(git describe --tags)"
}
```

### ARM64 Custom

```bash
#!/bin/bash
# scripts/scripts.d/plugins/kernelsources/arm64_custom.sh

fetch_kernel() {
    echo "Fetching ARM64 kernel..."
    # Your ARM64-specific logic
}
```

## Smart Lookup

When configured in `ENV_EXTENSIONS`:
1. Checks `scripts/scripts.d/plugins/kernelsources/` first (custom implementations)
2. Falls back to `scripts/plugins/kernelsources/` if custom not found (official)

## See Also

- [Official kernel sources documentation](../../plugins/kernelsources/README.md)
- [Custom scripts documentation](../README.md)
