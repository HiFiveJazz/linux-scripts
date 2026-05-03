#!/usr/bin/env bash
set -euo pipefail

KERNEL_SRC="$HOME/linux/linux_stable"
VM_SRC="/usr/src/linux-current"
VM_HOST="archvm"

echo "[1/4] Syncing kernel source/build tree to VM..."

rsync -ah --info=progress2 --delete --delete-excluded \
  --exclude='.git/' \
  --exclude='vmlinux' \
  --exclude='vmlinux.o' \
  --exclude='vmlinux.a' \
  --exclude='vmlinux.unstripped' \
  --exclude='System.map' \
  --exclude='*.o' \
  --exclude='*.a' \
  --exclude='*.ko' \
  --exclude='*.ko.*' \
  --exclude='*.mod' \
  --exclude='*.mod.c' \
  "$KERNEL_SRC/" "$VM_HOST:$VM_SRC/"

echo "[2/4] Verifying synced Rust/kernel metadata in VM..."

ssh "$VM_HOST" bash -s <<'EOF'
set -euo pipefail

cd /usr/src/linux-current

echo "Kernel tree: $(pwd)"
echo "Kernel release from source:"
make -s kernelrelease || true

echo
echo "Checking key metadata files:"
ls -lh Module.symvers modules.order modules.builtin modules.builtin.modinfo 2>/dev/null || true

echo
echo "Checking Rust metadata:"
ls -lh rust/libcore.rmeta rust/libkernel.rmeta rust/libcompiler_builtins.rmeta 2>/dev/null || true

echo
echo "Checking Rust config:"
grep -E '^CONFIG_RUST=|^CONFIG_HAVE_RUST=' .config || true

echo
echo "Checking Rust compiler:"
rustc --version --verbose | grep -E 'rustc |commit-hash|commit-date|LLVM version'
EOF

echo "[3/4] Rust artifact state before rebuild-drivers.sh..."
ssh "$VM_HOST" bash -s <<'EOF'
set -euo pipefail
cd /usr/src/linux-current

echo "Before:"
make -s kernelrelease || true
grep -E '^CONFIG_RUST=|^CONFIG_HAVE_RUST=' .config || true

sha256sum \
  rust/libcore.rmeta \
  rust/libkernel.rmeta \
  rust/libcompiler_builtins.rmeta \
  2>/dev/null || true
EOF

echo "[4/4] Rebuilding drivers inside VM..."
ssh "$VM_HOST" /root/scripts/rebuild-drivers.sh

echo "[post] Rust artifact state after rebuild-drivers.sh..."
ssh "$VM_HOST" bash -s <<'EOF'
set -euo pipefail
cd /usr/src/linux-current

echo "After:"
make -s kernelrelease || true
grep -E '^CONFIG_RUST=|^CONFIG_HAVE_RUST=' .config || true

sha256sum \
  rust/libcore.rmeta \
  rust/libkernel.rmeta \
  rust/libcompiler_builtins.rmeta \
  2>/dev/null || true
EOF
