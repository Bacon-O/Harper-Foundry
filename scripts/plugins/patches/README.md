# Kernel Patches Plugin

This directory contains plugins for applying patches to the Linux kernel source tree during the build process.

## Creating New Patch Plugins

To add a new kernel patch:

1. Create a new script in this directory (e.g., `rt-patch.sh`)
2. Follow this template:

```bash
#!/bin/bash

apply_my_patch() {
    echo "💉 Applying my custom patch..."
    
    if [ -n "$MY_PATCH_URL" ]; then
        if curl -fLo my-patch.patch "$MY_PATCH_URL"; then
            if patch -p1 < my-patch.patch; then
                echo "✅ Patch applied successfully!"
                export MY_PATCH_APPLIED="true"
            else
                echo "⚠️ Patch failed to apply."
                export MY_PATCH_APPLIED="false"
            fi
        fi
    fi
}

# Run if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    apply_my_patch
fi
```

3. Make it executable: `chmod +x rt-patch.sh`
4. Source it in your alloy mixture script:
   ```bash
   source "${PLUGIN_DIR}/patches/rt-patch.sh"
   ```
5. Add configuration to params file:
   ```bash
   MY_PATCH_URL="https://example.com/my-patch.patch"
   ```

## Best Practices

- Always provide fallback behavior if patch fails
- Use descriptive environment variable exports
- Log patch application status clearly
- Test patches with different kernel versions
- Document patch compatibility in comments
