# QEMU User Emulation (ARM64 Hosts)

## Quick Summary

When cross-compiling x86_64 kernels on an ARM64 host, some build steps execute
x86_64 binaries. `qemu-x86_64-static` provides user-mode emulation so those
binaries can run on ARM64.

## Why It Is Needed

- Debian kernel packaging and helper tools may run target-arch binaries.
- Some post-build checks and QA steps invoke target tools.
- Without user-mode emulation, these steps fail on ARM64 hosts.

## Where It Is Used

In params files, this is referenced as:

```bash
HOST_QEMU_STATIC="/usr/bin/qemu-x86_64-static"
```

This path is used by scripts that need to run x86_64 binaries during a build.

## Install

On Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y qemu-user-static
```

Verify it exists:

```bash
ls -l /usr/bin/qemu-x86_64-static
```

## binfmt_misc (Automatic Execution)

Many systems register `qemu-x86_64-static` automatically (via `systemd-binfmt`
or `qemu-user-static` post-install). If x86_64 binaries still fail to run on
ARM64, you may need to enable `binfmt_misc` and register the handler manually.

Enable `binfmt_misc`:

```bash
sudo mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
```

Register the x86_64 handler:

```bash
sudo sh -c 'echo ":qemu-x86_64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-x86_64-static:OCF" > /etc/binfmt.d/qemu-x86_64.conf'
```

Reload binfmt handlers:

```bash
sudo systemctl restart systemd-binfmt || true
```

If your distro handles this automatically, you do not need these steps.

## Helper Script (Optional)

If you prefer a quick helper, run:

```bash
sudo bash scripts/plugins/tools/setup_qemu_binfmt.sh
```

This installs `qemu-user-static`, mounts `binfmt_misc`, registers the handler,
and reloads `systemd-binfmt` when available.

Note: The helper script only supports Debian/Ubuntu hosts. Other distros should
install and configure `binfmt_misc` manually.

## Security & Impact (Short)

- This is a system-wide change: x86_64 binaries will auto-run via QEMU on ARM64.
- It does not grant new privileges, but it does expand the attack surface.
- Use trusted packages only and disable/remove binfmt if you do not need it.

## Do I Need This On x86_64 Hosts?

No. Native x86_64 hosts do not need this. It is only required for ARM64 hosts
cross-compiling x86_64 kernels.
