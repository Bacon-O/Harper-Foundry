#!/bin/bash
# OCI ARM -> x86_64 Pipeline Test (Ultra Slim)
set -e # Exit on any error

# 1. Get Source (Debian 13 Backports)
apt-get source linux/trixie-backports
cd linux-*/

# 2. Generate the "Tiny" Config (The baseline)
make ARCH=x86_64 LLVM=1 tinyconfig

# 3. Layer your Harper Identity
# Ensure harper_tunes.config is available in the parent directory
./scripts/kconfig/merge_config.sh -m .config ../configs/harper_tunes.config

# 4. Mandatory: Clean up the Signing Keys
# This prevents the "No rule to make target debian/certs/..." error
scripts/config --disable SYSTEM_TRUSTED_KEYS
scripts/config --disable SYSTEM_REVOCATION_KEYS
scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""

# 5. Non-interactive update (Fills in mandatory tinyconfig gaps)
make ARCH=x86_64 LLVM=1 olddefconfig

# 6. The "Speed Demon" Build
# Note: we use bindeb-pkg to get those sweet .deb artifacts
make ARCH=x86_64 \
     LLVM=1 \
     CROSS_COMPILE=x86_64-linux-gnu- \
     -j$(nproc) bindeb-pkg

# 7. Success Notification
echo "✅ Pipeline Test Complete! Check for .deb files in the parent directory."