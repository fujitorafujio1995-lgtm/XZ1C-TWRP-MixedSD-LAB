#!/sbin/sh
set -eu

DEV="${XZ1C_SD_DEV:-/dev/block/mmcblk0}"

[ -b "$DEV" ] || {
    echo "SD card not found: $DEV"
    exit 1
}

SECTOR="$(blockdev --getss "$DEV")"
BYTES="$(blockdev --getsize64 "$DEV")"
SECTORS="$(blockdev --getsz "$DEV")"

TOTAL_GIB=$((BYTES / 1073741824))
REM=$((BYTES % 1073741824))
TENTHS=$((REM * 10 / 1073741824))

LAYOUT="none"

if command -v sgdisk >/dev/null 2>&1; then
    GPT="$(sgdisk -p "$DEV" 2>/dev/null || true)"

    echo "$GPT" | grep -q "android_meta" &&
    echo "$GPT" | grep -q "android_expand" &&
        LAYOUT="mixed"
fi

# Find TWRP command.
TWRP_BIN=""
for candidate in /sbin/twrp /system/bin/twrp; do
    if [ -x "$candidate" ]; then
        TWRP_BIN="$candidate"
        break
    fi
done

if [ -n "$TWRP_BIN" ]; then
    "$TWRP_BIN" set tw_xz1c_sd_loaded 1
    "$TWRP_BIN" set tw_xz1c_sd_total_gib "$TOTAL_GIB"
    "$TWRP_BIN" set tw_xz1c_sd_total_display "${TOTAL_GIB}.${TENTHS} GiB"
    "$TWRP_BIN" set tw_xz1c_sd_device "$DEV"
    "$TWRP_BIN" set tw_xz1c_sd_sector "$SECTOR"
    "$TWRP_BIN" set tw_xz1c_sd_bytes "$BYTES"
    "$TWRP_BIN" set tw_xz1c_sd_layout "$LAYOUT"

    # Initial UI value:
    # reserve 8 GiB minimum for portable and use the remainder for internal,
    # capped so both sides remain >= 8 GiB.
    if [ "$TOTAL_GIB" -ge 16 ]; then
        INITIAL_INTERNAL=$((TOTAL_GIB / 2))
        INITIAL_PORTABLE=$((TOTAL_GIB - INITIAL_INTERNAL))

        "$TWRP_BIN" set tw_xz1c_internal_gib "$INITIAL_INTERNAL"
        "$TWRP_BIN" set tw_xz1c_portable_gib "$INITIAL_PORTABLE"
    fi

    "$TWRP_BIN" set tw_xz1c_sd_status "SD loaded: ${TOTAL_GIB}.${TENTHS} GiB"
fi

echo "SD device: $DEV"
echo "Sector size: $SECTOR"
echo "Bytes: $BYTES"
echo "Capacity: ${TOTAL_GIB}.${TENTHS} GiB"
echo "Sectors: $SECTORS"
echo "Layout: $LAYOUT"

if [ "$LAYOUT" = "mixed" ]; then
    echo "Detected AOSP mixed-storage layout."
else
    echo "No AOSP mixed-storage layout detected."
fi
