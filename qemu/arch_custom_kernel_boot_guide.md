# Building and Booting a Custom Linux Kernel (Arch Linux)

This document records the exact steps used to compile and boot a custom Linux kernel on Arch Linux, including temporarily unbinding an NVMe drive from `vfio-pci` so `grub-mkconfig` can detect Windows.

---

# 1. Obtain Kernel Source

Example (if cloning upstream):

```bash
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux
```

In this setup the kernel source was already present:

```bash
cd ~/linux/linux_stable
```

---

# 2. Import Current Kernel Configuration

Use the running kernel config as a base.

```bash
zcat /proc/config.gz > .config
```

Or from a saved config:

```bash
zcat config.gz > linux_stable/.config
```

---

# 3. Update Config for the New Kernel

Make the configuration compatible with the new kernel version:

```bash
make olddefconfig
```

Optional: reduce modules to those currently in use:

```bash
lsmod > /tmp/my-lsmod
make LSMOD=/tmp/my-lsmod localmodconfig
```

---

# 4. Compile the Kernel

Use all CPU threads:

```bash
make -j$(nproc)
```

The compiled kernel image will appear at:

```
arch/x86/boot/bzImage
```

---

# 5. Install Kernel Modules

From the root of the kernel source tree:

```bash
sudo make modules_install
```

Modules will be installed to:

```
/usr/lib/modules/<kernel-version>/
```

Check the kernel version:

```bash
make kernelrelease
```

---

# 6. Copy the Kernel Image to /boot

```bash
sudo cp arch/x86/boot/bzImage /boot/vmlinuz-linux-dev
```

Optional but useful:

```bash
sudo cp System.map /boot/System.map-linux-dev
```

---

# 7. Generate Initramfs

```bash
sudo mkinitcpio -k $(make kernelrelease) -g /boot/initramfs-linux-dev.img
```

You should now have:

```
/boot/vmlinuz-linux-dev
/boot/initramfs-linux-dev.img
```

---

# 8. Temporarily Unbind NVMe from VFIO

If the Windows disk is bound to `vfio-pci`, `os-prober` cannot detect it.

Unbind it from VFIO:

```bash
echo "0000:bf:00.0" | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind
```

Bind it to the NVMe driver:

```bash
echo "0000:bf:00.0" | sudo tee /sys/bus/pci/drivers/nvme/bind
```

Verify:

```bash
lspci -nnk -s bf:00.0
```

Expected output:

```
Kernel driver in use: nvme
```

---

# 9. Regenerate GRUB Configuration

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

This should detect:

```
Found linux image: /boot/vmlinuz-linux-dev
Found Windows Boot Manager
```

---

# 10. Rebind NVMe Back to VFIO

After regenerating GRUB, return the device to `vfio-pci`.

Unbind from NVMe:

```bash
echo "0000:bf:00.0" | sudo tee /sys/bus/pci/drivers/nvme/unbind
```

Bind back to VFIO:

```bash
echo "0000:bf:00.0" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind
```

Verify:

```bash
lspci -nnk -s bf:00.0
```

Expected:

```
Kernel driver in use: vfio-pci
```

---

# 11. Reboot

```bash
reboot
```

Select the custom kernel from GRUB:

```
Arch Linux → linux-dev
```

---

# 12. Verify the Running Kernel

After boot:

```bash
uname -r
```

Example output:

```
7.0.0-rc2-g0031c06807cf
```

---

# 13. Check Kernel Warnings/Errors

```bash
sudo dmesg -l err,warn
```

This helps detect regressions.

---

# Result

Your system now has multiple kernels installed:

```
/boot/vmlinuz-linux
/boot/vmlinuz-linux-vfio
/boot/vmlinuz-linux-lts
/boot/vmlinuz-linux-hardened
/boot/vmlinuz-linux-dev   ← custom kernel
```

The custom kernel can be rebuilt and reinstalled without affecting the others.

---

# Useful Commands for Future Development

Rebuild kernel:

```bash
make -j$(nproc)
```

Reinstall modules:

```bash
sudo make modules_install
```

Update kernel image:

```bash
sudo cp arch/x86/boot/bzImage /boot/vmlinuz-linux-dev
```

Regenerate initramfs:

```bash
sudo mkinitcpio -k $(make kernelrelease) -g /boot/initramfs-linux-dev.img
```

Update GRUB:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```
