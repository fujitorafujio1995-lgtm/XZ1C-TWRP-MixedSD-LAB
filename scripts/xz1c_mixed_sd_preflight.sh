#!/sbin/sh
set -eu
DEV="${XZ1C_SD_DEV:-/dev/block/mmcblk0}"
command -v blockdev >/dev/null
command -v sgdisk >/dev/null
[ -b "$DEV" ]
echo "device=$DEV"
echo "sector=$(blockdev --getss "$DEV")"
echo "bytes=$(blockdev --getsize64 "$DEV")"
sgdisk -p "$DEV" || true
