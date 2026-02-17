# Custom Patches

Add custom kernel patches here. These are applied during build if configured.

## Purpose

Apply custom modifications to the kernel:
- Security patches
- Performance tunings
- Bug fixes
- Feature additions
- Architecture-specific optimizations

## File Format

Place `.patch` files directly in this directory.

```bash
scripts/scripts.d/plugins/patches/
├── security_hardening.patch
├── bpf_optimizations.patch
├── custom_driver.patch
└── my_feature.patch
```

## Patch Format

Standard unified diff format:

```patch
--- a/file.c
+++ b/file.c
@@ -10,3 +10,5 @@
 original line 1
 original line 2
+new line 1
+new line 2
```

## Creating Patches

### From Git

```bash
git diff HEAD~1 > my.patch
```

### From Modified Kernel Tree

```bash
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
