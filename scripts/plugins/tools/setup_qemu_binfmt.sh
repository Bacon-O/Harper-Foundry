#!/bin/bash
set -euo pipefail

# Helper tool: set up qemu-x86_64-static and binfmt_misc for ARM64 hosts.
# This script is standalone and does not depend on the rest of Harper Foundry.

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "❌ Missing command: $1"
        exit 1
    fi
}

is_debian_family="false"
if [[-f /etc/os-release ]]; then
    os_id=$(. /etc/os-release; echo "$ID")
    os_like=$(. /etc/os-release; echo "$ID_LIKE")
    case "$os_id" in
        debian|ubuntu)
            is_debian_family="true"
            ;;
    esac
    if [["$is_debian_family" != "true" ] && echo "$os_like" | grep -Eq "(^|\s)(debian|ubuntu)(\s|$)"; then
        is_debian_family="true"
    fi
elif [[-f /etc/debian_version ]]; then
    is_debian_family="true"
fi

if [["$is_debian_family" != "true" ]]; then
    echo "❌ This helper only supports Debian/Ubuntu hosts."
    echo "   Install qemu-user-static and binfmt_misc manually on this distro."
    exit 1
fi

if [["${EUID}" -ne 0 ]]; then
    echo "⚠️  This helper uses sudo for system-wide changes."
    echo "   You may be prompted for your password."
fi

require_cmd sudo
require_cmd mount
require_cmd sh

echo "🔧 Installing qemu-user-static (if needed)..."
sudo apt-get update -y
sudo apt-get install -y qemu-user-static

if [[! -e /proc/sys/fs/binfmt_misc ]]; then
    echo "❌ binfmt_misc not available at /proc/sys/fs/binfmt_misc"
    echo "   Ensure the binfmt_misc kernel module is enabled."
    exit 1
fi

if ! mountpoint -q /proc/sys/fs/binfmt_misc; then
    echo "🔧 Mounting binfmt_misc..."
    sudo mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
fi

echo "🔧 Registering qemu-x86_64 binfmt handler..."
sudo sh -c 'echo ":qemu-x86_64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-x86_64-static:OCF" > /etc/binfmt.d/qemu-x86_64.conf'

if command -v systemctl >/dev/null 2>&1; then
    echo "🔧 Reloading systemd-binfmt..."
    sudo systemctl restart systemd-binfmt || true
fi

echo "✅ QEMU user emulation setup complete."
echo "   Verify: ls -l /usr/bin/qemu-x86_64-static"
