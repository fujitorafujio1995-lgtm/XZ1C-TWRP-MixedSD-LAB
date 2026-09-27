#!/sbin/sh
set -eu
DEV="${XZ1C_SD_DEV:-/dev/block/mmcblk0}"
sgdisk -p "$DEV" 2>/dev/null | grep -qi android_expand || exit 1
echo "Mixed layout detected; Android vold remains responsible for adopted storage activation."
