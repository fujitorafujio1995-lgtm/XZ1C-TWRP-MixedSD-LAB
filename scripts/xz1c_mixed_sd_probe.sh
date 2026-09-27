#!/sbin/sh
set -eu
DEV="${XZ1C_SD_DEV:-/dev/block/mmcblk0}"
[ -b "$DEV" ] || { echo "SD card not found: $DEV"; exit 1; }
SECTOR="$(blockdev --getss "$DEV")"
BYTES="$(blockdev --getsize64 "$DEV")"
TOTAL_GIB=$((BYTES / 1073741824))
REM=$((BYTES % 1073741824))
TENTHS=$((REM * 10 / 1073741824))
ALLOC_GIB="$TOTAL_GIB"
LAYOUT="none"
if command -v sgdisk >/dev/null 2>&1; then
  GPT="$(sgdisk -p "$DEV" 2>/dev/null || true)"
  if echo "$GPT" | grep -q "android_meta" && echo "$GPT" | grep -q "android_ext" && echo "$GPT" | grep -q "XZ1C_DOWNLOAD" && echo "$GPT" | grep -q "XZ1C_SWAP"; then
    LAYOUT="mixed"
  fi
fi
# Default: App + Public. Swap starts disabled.
APP=$((ALLOC_GIB * 60 / 100))
PUBLIC=$((ALLOC_GIB - APP))
SWAP=0
for TWRP_BIN in /sbin/twrp /system/bin/twrp; do
  if [ -x "$TWRP_BIN" ]; then
    "$TWRP_BIN" set tw_xz1c_sd_loaded 1
    "$TWRP_BIN" set tw_xz1c_sd_total_gib "$TOTAL_GIB"
    "$TWRP_BIN" set tw_xz1c_sd_total_display "${TOTAL_GIB}.${TENTHS} GiB"
    "$TWRP_BIN" set tw_xz1c_sd_alloc_gib "$ALLOC_GIB"
    "$TWRP_BIN" set tw_xz1c_sd_device "$DEV"
    "$TWRP_BIN" set tw_xz1c_sd_sector "$SECTOR"
    "$TWRP_BIN" set tw_xz1c_sd_bytes "$BYTES"
    "$TWRP_BIN" set tw_xz1c_sd_layout "$LAYOUT"
    "$TWRP_BIN" set tw_xz1c_sd_app_gib "$APP"
    "$TWRP_BIN" set tw_xz1c_sd_public_gib "$PUBLIC"
    "$TWRP_BIN" set tw_xz1c_sd_swap_gib "$SWAP"
    "$TWRP_BIN" set tw_xz1c_sd_status "SD loaded: ${ALLOC_GIB} GiB usable allocation"
    break
  fi
done
echo "Capacity: ${TOTAL_GIB}.${TENTHS} GiB"
echo "Usable allocation: ${ALLOC_GIB} GiB"
echo "Default: App=${APP} Public=${PUBLIC} Swap=${SWAP}"
echo "Layout: $LAYOUT"
