# Custom Source Fetchers

Add custom source fetchers here to override or extend the official implementations.

**Reference in params:**
```bash
ENV_EXTENSIONS=("source_fetcher/mykernel.sh")
SOFTWARE_SOURCE="mykernel"
```

See [Official source fetcher documentation](../../plugins/source_fetcher/README.md) for the plugin interface.
    cd kernel_src
    git checkout my-branch
    SOFTWARE_SOURCE_PATH="$PWD"
    SOFTWARE_VERSION="$(git describe --tags)"
}
```

### ARM64 Custom

```bash
#!/bin/bash
# scripts/scripts.d/plugins/source_fetcher/arm64_custom.sh

fetch_kernel() {
    echo "Fetching ARM64 kernel..."
    # Your ARM64-specific logic
}
```

## Smart Lookup

When configured in `ENV_EXTENSIONS`:
1. Checks `scripts/scripts.d/plugins/source_fetcher/` first (custom implementations)
2. Falls back to `scripts/plugins/source_fetcher/` if custom not found (official)

## See Also

- [Official source fetcher documentation](../../plugins/source_fetcher/README.md)
- [Custom scripts documentation](../README.md)
