# Alloy Mixtures - Build Script Variants

This directory contains different "alloy mixtures" - build script variants optimized for different purposes. Think of them as different recipes for smelting the kernel, each tuned for specific goals.

## 🎯 Available Mixtures

### `full.sh` - Production Full Build
**Purpose:** Complete, production-ready kernel builds  
**Build Time:** 30-60+ minutes (depending on hardware)  
**Artifacts:** Full .deb packages, headers, bzImage  
**Use Case:** Production releases, complete feature set  

**Features:**
- Full Debian kernel configuration
- BORE scheduler patching (with EEVDF fallback)
- Complete tuning profile application
- All kernel modules
- Debian package generation (.deb, .changes, .buildinfo)
- Comprehensive artifact collection

**Usage:**
```bash
# In params/foundry.params or custom params file:
FOUNDRY_EXEC="alloymixtures/full.sh"

# Or via command line:
./start_build.sh --exec alloymixtures/full.sh
```

---

### `tinyconfig.sh` - Quick Test Build
**Purpose:** Fast pipeline validation and testing  
**Build Time:** 2-5 minutes  
**Artifacts:** bzImage only, minimal config  
**Use Case:** Testing foundry changes, CI/CD validation  

**Features:**
- Minimal kernel configuration (tinyconfig base)
- Essential bootable features only
- No scheduler patches (for speed)
- No modules compilation
- No package generation
- Just bzImage compilation

**Usage:**
```bash
# Using the dedicated params file:
./start_build.sh --config-file params/tinyconfig.foundry.params

# Or specify exec directly:
./start_build.sh --exec alloymixtures/tinyconfig.sh

# Or via make:
make test  # Uses tinyconfig by default
```

**What Gets Tested:**
- ✅ Environment setup
- ✅ Kernel source fetching
- ✅ Build toolchain functionality
- ✅ Compilation process
- ✅ Artifact collection
- ✅ Ownership/permission handling

**What Doesn't:**
- ❌ Full feature set
- ❌ Module compilation
- ❌ Package generation
- ❌ Production-ready kernel

---

## 📊 Comparison Matrix

| Feature | full.sh | tinyconfig.sh |
|---------|---------|---------------|
| Build Time | 30-60+ min | 2-5 min |
| Config Base | Debian default | tinyconfig |
| Scheduler Patch | ✅ Yes | ❌ No |
| Tuning Profile | ✅ Yes | ❌ No |
| Modules | ✅ All | ❌ None |
| .deb Packages | ✅ Yes | ❌ No |
| bzImage | ✅ Yes | ✅ Yes |
| Production Ready | ✅ Yes | ❌ No |
| Good for Testing | ⚠️ Slow | ✅ Fast |

---

## 🔧 Creating New Mixtures

To add a new alloy mixture:

1. **Create the script:**
   ```bash
   cp alloymixtures/full.sh alloymixtures/my-custom.sh
   ```

2. **Modify for your needs:**
   - Adjust configuration approach
   - Change compilation targets
   - Modify artifact collection
   - Update versioning scheme

3. **Create matching params file (optional):**
   ```bash
   cp params/foundry.params params/my-custom.foundry.params
   ```

4. **Update the params:**
   ```bash
   FOUNDRY_EXEC="alloymixtures/my-custom.sh"
   ```

5. **Document in this README**

### Common Mixture Ideas

- **`minimal.sh`** - Small footprint, embedded systems
- **`debug.sh`** - Full debug symbols, verbose output
- **`performance.sh`** - Optimized for benchmarking
- **`secure.sh`** - Hardened security features
- **`rt.sh`** - Real-time (PREEMPT_RT) kernel
- **`server.sh`** - Server-optimized configuration
- **`desktop.sh`** - Desktop/workstation optimized

---

## 🎨 Design Philosophy

The "alloy mixture" metaphor reflects the foundry theme:

- **Foundry** = Build system infrastructure
- **Alloy** = Kernel configuration + build process
- **Mixture** = Specific combination of settings

Different alloys have different properties:
- **Full build** = Strong, complete alloy (production metal)
- **Tinyconfig** = Light, fast alloy (test sample)
- **Custom builds** = Specialized alloys (specific applications)

Just as a metallurgist chooses different alloy compositions for different purposes, we choose different build mixtures based on our goals.

---

## 📝 Script Requirements

All alloy mixture scripts must:

1. **Source environment:**
   ```bash
   source /opt/factory/scripts/env_setup.sh "$@"
   ```

2. **Set up cleanup trap:**
   ```bash
   trap cleanup_internal EXIT
   ```

3. **Handle ownership:**
   ```bash
   chown -R "$HOST_UID:$HOST_GID" "$CONTAINER_OUTPUT_DIR"
   ```

4. **Exit cleanly:**
   - Exit 0 on success
   - Exit 1 on failure with clear error message

5. **Respect environment variables:**
   - `INCREMENTAL_BUILD`
   - `FINAL_JOBS`
   - `TARGET_ARCH`
   - All MAKE_* variables

---

## 🚀 Quick Reference

```bash
# Full production build
./start_build.sh --config-file params/foundry.params

# Quick test build
./start_build.sh --config-file params/tinyconfig.foundry.params

# Custom mixture
./start_build.sh --exec alloymixtures/my-custom.sh

# Override just the exec script
./start_build.sh -e alloymixtures/tinyconfig.sh
```

---

## 🧪 Testing New Mixtures

Before using a new mixture in production:

1. **Test with tinyconfig first:**
   ```bash
   ./start_build.sh --test-run --exec alloymixtures/my-new.sh
   ```

2. **Validate configuration:**
   ```bash
   ./scripts/validate_params.sh params/my-new.foundry.params
   ```

3. **Check output artifacts:**
   ```bash
   ./scripts/show_builds.sh
   ```

4. **Run QA tests:**
   ```bash
   # Ensure BYPASS_QA="false" in params
   ./scripts/material_analysis.sh
   ```

---

For more information, see the main [README.md](../../README.md) and [CONTRIBUTING.md](../../CONTRIBUTING.md).
