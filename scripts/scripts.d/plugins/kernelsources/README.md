# Custom Kernel Source Plugins

Add custom kernel source fetchers here to override or extend official plugins.

**Reference in params:**
```bash
ENV_EXTENSIONS=("kernelsources/mykernel.sh")
KERNEL_SOURCE="mykernel"
```

See [Official kernel sources](../../plugins/kernelsources/README.md) for plugin interface.
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
