#!/usr/bin/env bash
qemu-system-x86_64 \
  -cpu host \
  -enable-kvm \
  -m 4G \
  -smp 6 \
  -drive file=$HOME/GitHub/linux-scripts/qemu/arch.img,format=raw,if=virtio \
  -kernel /boot/vmlinuz-linux-dev \
  -initrd /boot/initramfs-linux-dev.img \
  -append "root=/dev/vda rw console=ttyS0 loglevel=7 earlyprintk=serial" \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:10022-:22 \
  -device virtio-net-pci,netdev=net0 \
  -nographic
