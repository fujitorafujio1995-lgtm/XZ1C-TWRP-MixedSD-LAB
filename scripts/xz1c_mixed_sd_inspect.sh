#!/sbin/sh
DEV="${XZ1C_SD_DEV:-/dev/block/mmcblk0}"
echo "device=$DEV"
blockdev --getss "$DEV" 2>/dev/null || true
blockdev --getsize64 "$DEV" 2>/dev/null || true
sgdisk -p "$DEV" 2>&1 || true
blkid "$DEV" "${DEV}p1" "${DEV}p2" "${DEV}p3" 2>/dev/null || true
ls -l /data/misc_de/0/expand_*.key 2>/dev/null || true
