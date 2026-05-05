#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/linux-mainline"
DEST="$CACHE_DIR/src"
REPO="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"

mkdir -p "$CACHE_DIR"

if [[ ! -d "$DEST/.git" ]]; then
    echo "No Git checkout found at: $DEST"
    echo "Cloning Linux kernel source..."

    rm -rf "$DEST"
    git clone --depth=1 --branch master "$REPO" "$DEST"
else
    echo "Updating existing Linux kernel checkout..."
    git -C "$DEST" fetch --depth=1 origin master
    git -C "$DEST" checkout master
    git -C "$DEST" reset --hard origin/master
fi

echo
echo "Kernel source ready at: $DEST"
echo "Current commit:"
git -C "$DEST" log -1 --oneline
