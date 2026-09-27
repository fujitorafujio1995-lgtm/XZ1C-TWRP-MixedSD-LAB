#!/sbin/sh
set -eu
DEV="${XZ1C_SD_DEV:-/dev/block/mmcblk0}"
[ -b "$DEV" ] || exit 1
sgdisk --zap-all "$DEV"
if command -v wipefs >/dev/null 2>&1; then wipefs -a "$DEV" || true; fi
sync
echo "SD partition layout cleared."
