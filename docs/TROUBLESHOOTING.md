# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the Harper Foundry.

## Table of Contents

- [Build Failures](#build-failures)
- [Configuration Issues](#configuration-issues)
- [Docker Problems](#docker-problems)
- [QA Test Failures](#qa-test-failures)
- [Performance Issues](#performance-issues)
- [Common Error Messages](#common-error-messages)

## Quick Diagnostics

Run these commands to gather diagnostic information:

```bash
# Validate your configuration
./scripts/validate_params.sh

# Check Docker status
docker info

# Verify disk space
df -h

# Check build artifacts
ls -lh /path/to/HOST_OUTPUT_DIR/
```

## Build Failures

### Issue: "Kernel source not found"

**Symptoms:**
```
❌ ERROR: Kernel source not found
```

**Causes:**
- Invalid `KERNEL_SOURCE` in `params/foundry_template.params`
- Network issues preventing package download
- Debian repository not accessible

**Solutions:**
1. Check your `KERNEL_SOURCE` value:
   ```bash
   grep KERNEL_SOURCE params/foundry_template.params
   ```

2. Verify the package exists:
   ```bash
   apt-cache search linux-source
   ```

3. Try a different Debian mirror in the Dockerfile

### Issue: Compilation Errors



**Causes:**
- Missing dependencies in Docker image
- Incorrect cross-compilation toolchain setup
- Configuration conflicts

**Solutions:**
1. Check compiler version:
   ```bash
   docker run -it debian-harper-worker clang --version
   ```

2. Verify architecture variables:
   ```bash
   # In params/foundry_template.params, ensure these match:
   TARGET_ARCH="x86_64"
   CROSS_COMPILE_PREFIX="x86_64-linux-gnu-"
   BUILD_CC="clang --target=x86_64-linux-gnu"
   ```

3. Try a clean build:
   ```bash
   ./scripts/clean.sh --deep
   ./start_build.sh
   ```

### Issue: "Out of Memory" During Build

**Symptoms:**
```
virtual memory exhausted: Cannot allocate memory
```

**Solutions:**
1. Reduce parallelism:
   ```bash
   # In params/foundry_template.params
   PARALLEL_JOBS="4"  # Reduce from default
   ```

2. Increase Docker memory limit:
   ```bash
   # Edit Docker daemon settings
   # Linux: /etc/docker/daemon.json
   {
     "default-ulimits": {
       "memlock": {
         "Hard": -1,
         "Name": "memlock",
         "Soft": -1
       }
     }
   }
   ```

3. Free up system memory before building

## Configuration Issues

### Issue: Invalid Configuration Detected

**Symptoms:**
```
❌ Configuration has X error(s)
```

**Solution:**
Run the validation script and fix reported errors:
```bash
./scripts/validate_params.sh params/foundry_template.params
```

Common fixes:
- Ensure paths use absolute paths
- Verify all referenced files exist
- Check array syntax is correct

### Issue: Cross-Compilation Mismatch

**Symptoms:**
- Wrong architecture binaries produced
- "cannot execute binary file" errors

**Solution:**
Verify architecture consistency:
```bash
# These should align:
TARGET_ARCH="x86_64"              # Kernel arch
DEB_HOST_ARCH="amd64"            # Debian package arch
CROSS_COMPILE_PREFIX="x86_64-linux-gnu-"     # Toolchain prefix
BUILD_CC="clang --target=x86_64-linux-gnu"
```

### Issue: Configuration Merge Conflicts

**Symptoms:**
```
Value of CONFIG_xyz is redefined
```

**Solution:**
1. Check for conflicts between `BASE_CONFIG` and `TUNING_CONFIG`
2. Use `scripts/config` to verify final values:
   ```bash
   ./scripts/config --file .config --state CONFIG_OPTION
   ```

## Docker Problems

### Issue: Permission Denied

**Symptoms:**
```
permission denied while trying to connect to the Docker daemon
```

**Solutions:**
1. Add user to docker group:
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. Or use sudo:
   ```bash
   sudo ./start_build.sh
   ```

### Issue: Docker Build Fails

**Symptoms:**
```
ERROR [internal] load metadata for docker.io/library/debian:trixie-slim
```

**Solutions:**
1. Check network connectivity:
   ```bash
   ping deb.debian.org
   ```

2. Authenticate to Docker Hub if rate-limited:
   ```bash
   docker login
   ```

3. Use local mirror or cached image

### Issue: Container Cannot Access Files

**Symptoms:**
```
❌ ERROR: The Crucible (Block Volume) is not mounted at /build
```

**Solutions:**
1. Verify `BUILD_WORKSPACE_DIR` path exists and is accessible:
   ```bash
   ls -ld "$BUILD_WORKSPACE_DIR"
   ```

2. Check volume mount paths in `launch.sh`

3. Ensure SELinux/AppArmor allows Docker volume mounts:
   ```bash
   # For SELinux
   sudo setenforce 0
   ```

## QA Test Failures

### Issue: "No build artifacts found"

**Symptoms:**
```
❌ ERROR: No build artifacts found in /path/to/output
```

**Solutions:**
1. Check `HOST_OUTPUT_DIR` path in params
2. Verify the build completed successfully
3. Check ownership/permissions:
   ```bash
   ls -la "$HOST_OUTPUT_DIR"
   ```

### Issue: Missing Critical Configuration

**Symptoms:**
```
❌ CRITICAL FAILURE: CONFIG_xyz is MISSING
```

**Solutions:**
1. Add missing option to `TUNING_CONFIG`:
   ```bash
   echo "CONFIG_xyz=y" >> configs/your_tuning.config
   ```

2. Or remove from `QA_CRITICAL_CHECKS` if not actually required

3. Check if option name changed in newer kernel versions

### Issue: QEMU Test Fails

**Symptoms:**
```
❌ QEMU boot test failed
```

**Solutions:**
1. Verify QEMU is installed:
   ```bash
   which qemu-system-x86_64
   ```

2. Check if kernel is bootable:
   ```bash
   file /path/to/bzImage
   ```

3. Disable QEMU tests if not needed:
   ```bash
   # In params/foundry_template.params
   ENABLE_QEMU_TESTS="false"
   ```

## Performance Issues

### Issue: Build is Very Slow

**Symptoms:**
- Build takes hours instead of minutes

**Solutions:**
1. Increase parallelism:
   ```bash
   # In params/foundry_template.params
   PARALLEL_JOBS=""  # Empty = use all cores
   ```

2. Check CPU throttling:
   ```bash
   cat /proc/cpuinfo | grep MHz
   ```

3. Verify Docker has sufficient resources allocated

### Issue: Disk Space Filling Up

**Solutions:**
1. Clean old builds:
   ```bash
   ./scripts/clean.sh
   ```

2. Deep clean including Docker cache:
   ```bash
   ./scripts/clean.sh --deep
   ```

3. Prune Docker system:
   ```bash
   docker system prune -a
   ```

## Common Error Messages

### "cannot find -lelf"

**Cause:** Missing libelf development library in Docker image

**Solution:** Verify Dockerfile includes:
```dockerfile
RUN apt-get install -y libelf-dev:amd64
```

### "BTF: .tmp_vmlinux.btf: pahole (pahole) is not available"

**Cause:** BTF debug info enabled but pahole not installed

**Solution:** Disable BTF in configuration:
```bash
./scripts/config --disable DEBUG_INFO_BTF
```

### "No rule to make target 'debian/certs/...' needed by 'certs/x509_certificate_list'"

**Cause:** Debian signing keys not stripped

**Solution:** Verify `scripts/compile_scripts/harper_deb13.sh` includes:
```bash
./scripts/config --set-str MODULE_SIG_KEY ""
./scripts/config --set-str SYSTEM_TRUSTED_KEYS ""
```

### "dpkg-source: error: LC_ALL=C... returned exit status 2"

**Cause:** Debian source package extraction failure

**Solutions:**
1. Check available disk space
2. Verify network connectivity 
3. Try different kernel source version

## Getting More Help

If you're still stuck:

1. **Check the logs:**
   - Docker build logs
   - Kernel compilation output
   - QA test results

2. **Search existing issues:**
   - GitHub Issues tab
   - Known problems in README

3. **Create a detailed issue:**
   - Include OS and Docker version
   - Attach relevant logs
   - Describe steps to reproduce
   - Share your `foundry_template.params` (sanitize paths)

4. **Join the community:**
   - Discord/IRC/Forum links (if applicable)

## Debug Mode

Enable verbose output for troubleshooting:

```bash
# Add to start of any script
set -x  # Print each command before execution
set -v  # Print shell input lines as they are read

# Or run with bash -x
bash -x ./start_build.sh
```

## Validation Checklist

Before reporting an issue, confirm:

- [ ] Configuration is valid (`./scripts/validate_params.sh`)
- [ ] Docker is running (`docker info`)
- [ ] Sufficient disk space available (`df -h`)
- [ ] All paths in params exist
- [ ] Scripts have execute permissions (`chmod +x scripts/*.sh`)
- [ ] Latest code from repository (`git pull`)
- [ ] No local modifications causing conflicts (`git status`)
