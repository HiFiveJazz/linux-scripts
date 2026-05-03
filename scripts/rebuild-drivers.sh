#!/usr/bin/env bash
set -euo pipefail

KREL="$(uname -r)"

echo "[cleanup] removing old /lib/modules entries, keeping current kernel: $KREL"

find /lib/modules \
  -maxdepth 1 \
  -mindepth 1 \
  -type d \
  ! -name "$KREL" \
  -print \
  -exec rm -rf {} +

KERNEL_SRC="/usr/src/linux-current"

echo "[1/3] Running kernel: $KREL"

if [[ ! -d "$KERNEL_SRC" ]]; then
  echo "Missing kernel source at: $KERNEL_SRC"
  echo "Sync it from host first, for example:"
  echo "  rsync -ah --info --delete ~/linux/linux_stable/ archvm:$KERNEL_SRC/"
  exit 1
fi

echo "[2/3] Preparing kernel source..."

cd "$KERNEL_SRC"

if [[ -f /proc/config.gz ]]; then
  zcat /proc/config.gz > .config
else
  echo "Missing /proc/config.gz"
  exit 1
fi

# Restore suffix like -00247-g08d0d3466664 when .git was not rsynced.
BASE="$(make kernelversion)"
SUFFIX="${KREL#${BASE}}"

echo "Base kernel version: $BASE"
echo "Local version suffix: $SUFFIX"

echo "$SUFFIX" > localversion

make olddefconfig
make modules_prepare

PREPARED_KREL="$(make kernelrelease)"

echo "Prepared kernel release: $PREPARED_KREL"

if [[ "$PREPARED_KREL" != "$KREL" ]]; then
  echo "ERROR: Prepared kernel release does not match running kernel."
  echo "running:  $KREL"
  echo "prepared: $PREPARED_KREL"
  exit 1
fi

echo "[3/3] Creating /lib/modules build/source links..."

mkdir -p "/lib/modules/$KREL"

ln -sfn "$KERNEL_SRC" "/lib/modules/$KREL/build"
ln -sfn "$KERNEL_SRC" "/lib/modules/$KREL/source"

echo "Done. Prepared kernel source for $KREL"
