# Kernel Patches Plugin

This directory contains plugins for applying patches to the Linux kernel source tree during the build process.

## Available Patches

### BORE Scheduler (`bore.sh`)

Applies the **BORE (Burst-Oriented Response Enhancer)** scheduler patch to improve interactive performance and responsiveness.

#### Configuration

Set in your params file:

```bash
# BORE Scheduler Patch (optional)
BORE_PATCH_URL="https://github.com/firelzrd/bore-scheduler/releases/download/6.18.y-bore5.9.9/6.18.y-bore5.9.9.patch"
```

If `BORE_PATCH_URL` is not set or empty, the default EEVDF scheduler will be used.

#### Exports

The plugin sets these environment variables:

- `SCHEDULER_LABEL`: Either `"bore"` or `"eevdf"`
- `SCHED_PRIORITY`: `"2"` for BORE, `"1"` for EEVDF (used in package versioning)

#### Behavior

1. Downloads patch from `BORE_PATCH_URL`
2. Applies patch with `patch -p1 -F3`
3. On success: Sets `SCHEDULER_LABEL="bore"` and `SCHED_PRIORITY="2"`
4. On failure: Falls back to EEVDF scheduler with warning

#### Usage

The plugin is automatically sourced by alloy mixture scripts:

```bash
# In scripts/alloymixtures/harper_deb13..sh
source "${PLUGIN_DIR}/patches/bore.sh"
```

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
