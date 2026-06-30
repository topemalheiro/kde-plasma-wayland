#!/bin/bash
# Fix missing systemd-boot entry on Arch install
# Run from Arch live USB when ESP is /dev/nvme0n1p1 and btrfs root is /dev/nvme0n1p2

set -euo pipefail

ESP="/dev/nvme0n1p1"
ROOT="/dev/nvme0n1p2"
MOUNT="/mnt"

if [ "$(id -u)" -ne 0 ]; then
    echo "Must be run as root" >&2
    exit 1
fi

mkdir -p "$MOUNT"
mount "$ESP" "$MOUNT"

ROOT_UUID=$(lsblk -no UUID "$ROOT")
if [ -z "$ROOT_UUID" ]; then
    echo "Failed to get UUID for $ROOT" >&2
    umount "$MOUNT" || true
    exit 1
fi

cat > "$MOUNT/loader/entries/arch-linux.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rw rootflags=subvol=@ quiet
EOF

cat > "$MOUNT/loader/loader.conf" <<EOF
default arch-linux.conf
timeout 5
console-mode max
EOF

echo "Created boot entry:"
cat "$MOUNT/loader/entries/arch-linux.conf"
echo ""
echo "Updated loader.conf:"
cat "$MOUNT/loader/loader.conf"

umount "$MOUNT"
echo "Done. You can now reboot."
