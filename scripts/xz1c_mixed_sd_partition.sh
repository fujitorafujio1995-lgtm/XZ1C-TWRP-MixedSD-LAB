#!/sbin/sh
set -eu

DEV="${XZ1C_SD_DEV:-/dev/block/mmcblk0}"
INTERNAL="${1:-}"
PORTABLE="${2:-}"

[ -b "$DEV" ] || {
    echo "SD device not found: $DEV"
    exit 1
}

[ -n "$INTERNAL" ] && [ -n "$PORTABLE" ] || {
    echo "usage: partition.sh INTERNAL_GIB PORTABLE_GIB"
    exit 1
}

case "$INTERNAL:$PORTABLE" in
    *[!0-9:]*|"")
        echo "invalid partition sizes"
        exit 1
        ;;
esac

SECTOR="$(blockdev --getss "$DEV")"
BYTES="$(blockdev --getsize64 "$DEV")"
SECTORS="$(blockdev --getsz "$DEV")"

[ "$SECTOR" -eq 512 ] || {
    echo "unsupported sector size: $SECTOR"
    exit 1
}

# Re-read REAL capacity. UI values are never trusted as capacity.
TOTAL_BYTES="$BYTES"

# Minimum 8 GiB on each side.
[ "$INTERNAL" -ge 8 ] || exit 1
[ "$PORTABLE" -ge 8 ] || exit 1

# Convert requested GiB to bytes.
INTERNAL_BYTES=$((INTERNAL * 1073741824))
PORTABLE_BYTES=$((PORTABLE * 1073741824))

# AOSP-style layout:
#   P1 shared          = portable
#   P2 android_meta    = 16 MiB
#   P3 android_expand  = internal
#
# Keep the first usable sector at 2048 and reserve the final 34 sectors
# for the backup GPT.
FIRST=2048
GPT_RESERVED=34

P1_SECTORS=$((PORTABLE_BYTES / SECTOR))
P2_SECTORS=$((16 * 1024 * 1024 / SECTOR))
P3_SECTORS=$((INTERNAL_BYTES / SECTOR))

P1_START="$FIRST"
P1_END=$((P1_START + P1_SECTORS - 1))

P2_START=$((P1_END + 1))
P2_END=$((P2_START + P2_SECTORS - 1))

P3_START=$((P2_END + 1))
P3_END=$((P3_START + P3_SECTORS - 1))

# Never allow P3 to touch the backup GPT area.
LAST_USABLE=$((SECTORS - GPT_RESERVED - 1))

[ "$P3_END" -le "$LAST_USABLE" ] || {
    echo "requested layout does not fit real SD card"
    echo "internal=${INTERNAL}GiB portable=${PORTABLE}GiB"
    exit 1
}

# Also verify against the actual byte capacity.
REQUESTED_BYTES=$((PORTABLE_BYTES + INTERNAL_BYTES + 16 * 1024 * 1024))
[ "$REQUESTED_BYTES" -le "$TOTAL_BYTES" ] || {
    echo "requested size exceeds real SD capacity"
    exit 1
}

KEYDIR=/data/misc_de/0
KEYFILE="$KEYDIR/expand_xz1c.key"

mkdir -p "$KEYDIR"

# Preserve an existing AOSP expand key when present.
if [ ! -s "$KEYFILE" ]; then
    OLD="$(ls "$KEYDIR"/expand_*.key 2>/dev/null | head -n 1 || true)"

    if [ -n "$OLD" ] && [ -s "$OLD" ]; then
        cp "$OLD" "$KEYFILE"
    else
        head -c 16 /dev/urandom > "$KEYFILE"
    fi

    chmod 600 "$KEYFILE"
fi

# IMPORTANT:
# This is the only destructive point in Create partitions.
sgdisk --zap-all "$DEV"

# Create exact requested layout.
sgdisk \
    --new=1:${P1_START}:${P1_END} \
    --typecode=1:EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 \
    --change-name=1:shared \
    "$DEV"

sgdisk \
    --new=2:${P2_START}:${P2_END} \
    --typecode=2:19A710A2-B3CA-11E4-B026-10604B889DCF \
    --change-name=2:android_meta \
    "$DEV"

sgdisk \
    --new=3:${P3_START}:${P3_END} \
    --typecode=3:193D1EA4-B3CA-11E4-B075-10604B889DCF \
    --change-name=3:android_expand \
    "$DEV"

# Let GPT choose globally unique GUIDs.
sgdisk --randomize-guids "$DEV"

# Verify GPT before touching the filesystem.
sgdisk --verify "$DEV"

# The portable/public partition is the only filesystem TWRP creates.
command -v mkexfatfs >/dev/null 2>&1 || {
    echo "mkexfatfs not found"
    exit 1
}

mkexfatfs -n XZ1C_SHARED "${DEV}p1"

sync

echo "Created AOSP-style mixed layout"
echo "Device:   $DEV"
echo "Capacity: $TOTAL_BYTES bytes"
echo "Internal: ${INTERNAL} GiB"
echo "Portable: ${PORTABLE} GiB"
echo "Metadata: 16 MiB"
echo "P1:       ${P1_START}-${P1_END}"
echo "P2:       ${P2_START}-${P2_END}"
echo "P3:       ${P3_START}-${P3_END}"
