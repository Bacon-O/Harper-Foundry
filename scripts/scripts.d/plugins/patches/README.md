# Custom Patches

Add custom `.patch` files here to apply to the kernel during build.

Place unified diff format patches directly in this directory:
```bash
scripts/scripts.d/plugins/patches/
├── security.patch
├── performance.patch
└── feature.patch
```

Reference in your compile script to apply them.
diff -u original/file.c modified/file.c > custom.patch
```

## Usage

Patches are applied automatically during kernel compilation if they exist in:

```bash
scripts/scripts.d/plugins/patches/
```

## Testing Patches

```bash
# Test patch applies cleanly
patch --dry-run < scripts/scripts.d/plugins/patches/my.patch

# Apply it
patch < scripts/scripts.d/plugins/patches/my.patch
```

## Smart Lookup

Patches from `scripts/scripts.d/plugins/patches/` are applied before official patches from `scripts/plugins/patches/`.

## Examples

### Security Hardening

```patch
--- a/kernel/sysctl.c
+++ b/kernel/sysctl.c
@@ -123,6 +123,8 @@ static int kptr_restrict = 1;
+static int kptr_restrict = 2;
+// Restrict kernel pointer exposure for security
```

### Performance Tuning

```patch
--- a/kernel/sched/core.c
+++ b/kernel/sched/core.c
@@ -456,3 +456,5 @@ static const struct sysctl_table sched_table[] = {
+.min_vruntime_ns = 100000,  // Increase for lower latency
```

## See Also

- [Official patches documentation](../../plugins/patches/README.md)
- [Custom scripts documentation](../README.md)
