# Kernel Patches Plugin

This directory contains plugins for applying patches to the Linux kernel source tree during the build process.

## Directory Structure

```
patches/
├── README.md                   # This file

scripts.d/plugins/patches/      # Your custom patches (gitignored)
└── (your custom patches here)
```

## Creating New Patch Plugins

For user custom patches (recommended):

1. Create a new script in `scripts/scripts.d/plugins/patches/` (e.g., `scripts/scripts.d/plugins/patches/my-realtime.sh`)
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

3. Make it executable: `chmod +x scripts/scripts.d/plugins/patches/my-realtime.sh`
4. Source it in your compile script:
   ```bash
   # From custom patches
   source "${REPO_ROOT}/scripts/scripts.d/plugins/patches/my-realtime.sh`
   ```
5. Add configuration to params file:
   ```bash
   MY_PATCH_URL="https://example.com/my-patch.patch"
   ```

**Benefits of using `scripts/scripts.d/plugins/patches/`:**
- ✅ No git conflicts during updates
- ✅ Keeps custom patches separate from project
- ✅ Easy to maintain multiple patch sets
- ✅ Safe to do `git pull`

## Contributing Patches to Harper Foundry

For patches you want to contribute back:

1. Create a new script in `patches/` (e.g., `patches/openzfs.sh`)
2. Follow the template above
3. Update `scripts/alloymixtures/` to use your patch as needed
4. Document the patch and its requirements in comments
5. Submit a pull request with test results

## Best Practices

- Always provide fallback behavior if patch fails
- Use descriptive environment variable exports
- Log patch application status clearly
- Test patches with different kernel versions
- Document patch compatibility in comments
