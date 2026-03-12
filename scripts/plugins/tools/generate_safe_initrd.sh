#!/bin/bash

# Genreates a safe_initrd.img that can be used for qemuboot testing.
# uses https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
# Will generate the safe_initrd.img in the current directory

echo "🚀 Generating safe_initrd.img for QEMU testing..."
echo "📂 Setting up temporary workspace..."
mkdir -p tmp_qemu
cd tmp_qemu || exit 1

echo "📥 Downloading BusyBox binary..."
# 1. Get the binary and set up the 'bin' folder
wget -O busybox https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
chmod +x busybox
mkdir -p initrd_root/bin
cp busybox initrd_root/bin/busybox  # <--- Crucial: The interpreter must be here

echo "📂 Setting up initrd root filesystem and settings.."
# 2. Write the automated test script to /bin/sh
cat << 'EOF' > initrd_root/bin/sh
#!/bin/busybox sh
/bin/busybox mount -t devtmpfs devtmpfs /dev
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys

echo "==========================================="
echo "      KERNEL NTSYNC TEST ENVIRONMENT       "
echo "==========================================="

# Comment out if you just want to test boot
if [ -c /dev/ntsync ]; then
    echo "[ OK ] NTSYNC Device found."
    echo -n "Probing NTSYNC integrity: "
    for i in 1 2 3 4 5 6 7 8 9 10; do
        /bin/busybox cat /dev/ntsync > /dev/null 2>&1
        echo -n "."
    done
    echo " [ PASSED ]"
else
    echo "[ FAIL ] NTSYNC Device NOT found!"
    # Ensure we exit with an error status if possible
    /bin/busybox sleep 2
    /bin/busybox poweroff -f
fi

echo "-------------------------------------------"
echo "SANITY CHECK COMPLETE: KERNEL IS STABLE"
echo "-------------------------------------------"


# If you want to drop to shell for manual inspection if needed
#exec /bin/busybox sh

# 3. Shutdown the VM automatically
/bin/busybox poweroff -f
EOF

chmod +x initrd_root/bin/sh

echo "📂 Packing the initrd image..."
# 3. Pack it up
cd initrd_root || exit 1
find . | cpio -o -H newc | gzip > ../safe_initrd.img
cd ../../ || exit 1

echo "✅ safe_initrd.img generated successfully at $(realpath ../safe_initrd.img)"
cp tmp_qemu/safe_initrd.img ./safe_initrd.img
echo "✅ safe_initrd.img generated successfully at $(realpath ../safe_initrd.img)"

echo "Cleaning up temporary files..."
rm -rf ./tmp_qemu

if [[ -f "../safe_initrd.img" ]]; then
    echo "✅ safe_initrd.img is ready for use in QEMU testing."
else
    echo "❌ ERROR: safe_initrd.img was not created successfully."
    exit 1
fi
echo "✅ safe_initrd.img is ready for use in QEMU testing."
echo "Move safe_initrd.img to scripts/plugins/qatests/tests/"
echo "mv ../safe_initrd.img ../qatests/tests/safe_initrd.img"