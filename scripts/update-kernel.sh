#!/usr/bin/env bash
set -euo pipefail

KERNEL_DIR="$HOME/linux/linux_stable"
SAVED_CONFIG="$HOME/linux/config.gz"

BOOT_NAME="linux-dev"
KERNEL_IMAGE="/boot/vmlinuz-${BOOT_NAME}"
INITRAMFS_IMAGE="/boot/initramfs-${BOOT_NAME}.img"
SYSTEM_MAP="/boot/System.map-${BOOT_NAME}"

VFIO_PCI_ID="0000:bf:00.0"
DO_VFIO_REBIND=1

RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-nightly-2026-05-01-x86_64-unknown-linux-gnu}"
FORCE_CLEAN="${FORCE_CLEAN:-0}"

cd "$KERNEL_DIR"

echo "[1/10] Fetching latest upstream kernel..."
git fetch origin
git checkout master
git pull --ff-only origin master

echo "[2/10] Importing config..."
if [[ -f "$SAVED_CONFIG" ]]; then
    zcat "$SAVED_CONFIG" > .config
elif [[ -f /proc/config.gz ]]; then
    zcat /proc/config.gz > .config
else
    echo "No config found."
    exit 1
fi

echo "[3/10] Forcing QEMU VM networking drivers built-in..."
scripts/config --enable VIRTIO
scripts/config --enable VIRTIO_MENU
scripts/config --enable VIRTIO_PCI
scripts/config --enable VIRTIO_PCI_LEGACY
scripts/config --enable VIRTIO_NET

# Optional: keep e1000 built-in too, in case you boot QEMU with model=e1000.
scripts/config --enable E1000
scripts/config --enable E1000E

echo "[3.4/10] Setting Rust toolchain for kernel build..."
rustup toolchain install "$RUST_TOOLCHAIN" --profile minimal --component rust-src
rustup override set "$RUST_TOOLCHAIN"

echo "Using rustc:"
rustc --version --verbose | grep -E 'rustc |commit-hash|commit-date|LLVM version'

echo "[3.5/10] Enabling Rust support..."
scripts/config --enable RUST

echo "[4/10] Updating config..."
make olddefconfig
grep -E '^CONFIG_RUST=|^CONFIG_HAVE_RUST=' .config || true
gzip -c .config > "$SAVED_CONFIG" #Added later, may need to comment out

echo "[4.6/10] Checking Rust support..."
make rustavailable

if [[ "$FORCE_CLEAN" -eq 1 ]]; then
    echo "[4.6/10] Cleaning build tree..."
    make clean
fi

echo "[5/10] Building kernel..."
make -j"$(nproc)"

KREL="$(make kernelrelease)"
echo "Kernel release: $KREL"

echo "[6/10] Installing modules..."
sudo make modules_install

echo "[7/10] Installing kernel image..."
sudo cp arch/x86/boot/bzImage "$KERNEL_IMAGE"
sudo cp System.map "$SYSTEM_MAP"

echo "[8/10] Generating initramfs..."
sudo mkinitcpio -k "$KREL" -g "$INITRAMFS_IMAGE"

if [[ "$DO_VFIO_REBIND" -eq 1 ]]; then
    echo "[9/10] Temporarily rebinding NVMe from vfio-pci to nvme..."

    if [[ -e "/sys/bus/pci/devices/$VFIO_PCI_ID/driver/unbind" ]]; then
        CURRENT_DRIVER="$(basename "$(readlink "/sys/bus/pci/devices/$VFIO_PCI_ID/driver")")"
        echo "Current driver: $CURRENT_DRIVER"

        if [[ "$CURRENT_DRIVER" == "vfio-pci" ]]; then
            echo "$VFIO_PCI_ID" | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind >/dev/null
            echo "$VFIO_PCI_ID" | sudo tee /sys/bus/pci/drivers/nvme/bind >/dev/null || true
        fi
    fi
fi

echo "[10/10] Regenerating GRUB..."
sudo grub-mkconfig -o /boot/grub/grub.cfg

if [[ "$DO_VFIO_REBIND" -eq 1 ]]; then
    echo "Rebinding NVMe back to vfio-pci..."

    if [[ -e "/sys/bus/pci/devices/$VFIO_PCI_ID/driver/unbind" ]]; then
        CURRENT_DRIVER="$(basename "$(readlink "/sys/bus/pci/devices/$VFIO_PCI_ID/driver")")"
        echo "Current driver: $CURRENT_DRIVER"

        if [[ "$CURRENT_DRIVER" == "nvme" ]]; then
            echo "$VFIO_PCI_ID" | sudo tee /sys/bus/pci/drivers/nvme/unbind >/dev/null
            echo "$VFIO_PCI_ID" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind >/dev/null || true
        fi
    fi
fi

echo
echo "Done."
echo "Installed: $KERNEL_IMAGE"
echo "Initramfs: $INITRAMFS_IMAGE"
echo "Kernel release: $KREL"
echo
echo "Reboot and select linux-dev from GRUB."
