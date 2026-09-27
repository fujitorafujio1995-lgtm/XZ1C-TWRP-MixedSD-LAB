#!/system/bin/sh
set -u
DEV=/dev/block/mmcblk0

echo "XZ1C Mixed SD LAB inspection"
echo "Device: $DEV"

if [ ! -b "$DEV" ]; then
  echo "ERROR: removable SD block device not found"
  exit 1
fi

SIZE=$(blockdev --getsize64 "$DEV" 2>/dev/null || echo 0)
echo "Bytes: $SIZE"
if [ "$SIZE" -gt 0 ]; then
  awk -v s="$SIZE" 'BEGIN {printf "GiB: %.2f\\n", s/1024/1024/1024}'
fi

echo "--- GPT ---"
if [ -x /system/bin/sgdisk ]; then
  /system/bin/sgdisk -p "$DEV" || true
else
  echo "sgdisk not available in recovery"
fi

echo "NO PARTITION WAS MODIFIED"
exit 0
