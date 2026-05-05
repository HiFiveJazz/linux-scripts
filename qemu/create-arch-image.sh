#!/usr/bin/env bash
set -euo pipefail

IMG="$HOME/linux/qemu/arch.img"
MNT="/mnt/archvm"
SIZE="30G"

sudo pacman -S --needed qemu-base arch-install-scripts

mkdir -p "$(dirname "$IMG")"

if [[ -e "$IMG" ]]; then
  echo "Image already exists: $IMG"
  echo "Delete it first if you want to recreate it:"
  echo "  rm '$IMG'"
  exit 1
fi

qemu-img create -f raw "$IMG" "$SIZE"
mkfs.ext4 -F "$IMG"

LOOPDEV="$(sudo losetup --find --show -P "$IMG")"
echo "Using loop device: $LOOPDEV"

cleanup() {
  set +e
  sudo umount -R "$MNT" 2>/dev/null
  sudo losetup -d "$LOOPDEV" 2>/dev/null
}
trap cleanup EXIT

sudo mkdir -p "$MNT"
sudo mount "$LOOPDEV" "$MNT"

sudo pacstrap -K "$MNT" \
  base \
  linux-firmware \
  openssh \
  sudo \
  vim \
  tmux \
  git \
  strace \
  less \
  iproute2 \
  dhcpcd \
  iptables

sudo genfstab -U "$MNT" | sudo tee "$MNT/etc/fstab" >/dev/null

sudo arch-chroot "$MNT" /bin/bash <<'EOF'
set -euo pipefail

echo archvm > /etc/hostname

cat > /etc/hosts <<'HOSTS'
127.0.0.1 localhost
::1 localhost
127.0.1.1 archvm.localdomain archvm
HOSTS

systemctl enable sshd
systemctl enable dhcpcd
systemctl enable serial-getty@ttyS0.service

# For a throwaway local VM, this allows root console login with no password.
# You may prefer setting a real password instead.
passwd -d root

mkdir -p /root/.ssh
chmod 700 /root/.ssh
EOF

KEY="$HOME/.ssh/archvm_ed25519_linux_dev"

if [[ ! -f "$KEY" ]]; then
  ssh-keygen -t ed25519 -C "archvm" -f "$KEY"
else
  echo "SSH key already exists: $KEY"
fi

cat "$KEY.pub" | sudo tee "$MNT/root/.ssh/authorized_keys" >/dev/null
sudo chmod 700 "$MNT/root/.ssh"
sudo chmod 600 "$MNT/root/.ssh/authorized_keys"

echo "Done. Image created at: $IMG"
