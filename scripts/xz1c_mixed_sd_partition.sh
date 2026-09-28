#!/sbin/sh
set -eu

DEV="${XZ1C_SD_DEV:-/dev/block/mmcblk0}"
APP="${1:-0}"
PUBLIC="${2:-0}"
SWAP="${3:-0}"

[ -b "$DEV" ] || {
    echo "SD card not found: $DEV"
    exit 1
}

case "$APP:$PUBLIC:$SWAP" in
    *[!0-9:]*)
        echo "Invalid region sizes"
        exit 1
        ;;
esac

SECTOR="$(blockdev --getss "$DEV")"
BYTES="$(blockdev --getsize64 "$DEV")"

GIB=$((1024 * 1024 * 1024))
FIRST=2048
GPT_RESERVED=34
META_BYTES=$((16 * 1024 * 1024))

SECTORS=$((BYTES / SECTOR))

case "$DEV" in
    /dev/block/mmcblk[0-9]*)
        PART_PREFIX="${DEV}p"
        ;;
    *)
        PART_PREFIX="${DEV}"
        ;;
esac
LAST_USABLE=$((SECTORS - GPT_RESERVED))

# The 16 MiB hidden android_meta reservation is included exactly once here.
USER_BYTES=$((BYTES - FIRST * SECTOR - GPT_RESERVED * SECTOR - META_BYTES))

[ "$USER_BYTES" -gt 0 ] || {
    echo "SD card is too small"
    exit 1
}

TOTAL_GIB=$((USER_BYTES / GIB))
REQUESTED_GIB=$((APP + PUBLIC + SWAP))

# User regions may use less than MAX.
[ "$REQUESTED_GIB" -le "$TOTAL_GIB" ] || {
    echo "Requested ${REQUESTED_GIB} GiB exceeds usable ${TOTAL_GIB} GiB"
    exit 1
}

# Do not destroy the SD if the user selected nothing.
[ "$REQUESTED_GIB" -gt 0 ] || {
    echo "Enable at least one region"
    exit 1
}

CUR="$FIRST"
NEXT_NUM=1

PUB_NUM=0
META_NUM=0
APP_NUM=0
SWAP_NUM=0

PUB_START=0
PUB_END=0
META_START=0
META_END=0
APP_START=0
APP_END=0
SWAP_START=0
SWAP_END=0

calc_region()
{
    SIZE_BYTES="$1"

    SIZE_SECTORS=$((SIZE_BYTES / SECTOR))

    [ "$SIZE_SECTORS" -gt 0 ] || {
        echo "Partition size too small"
        exit 1
    }

    END=$((CUR + SIZE_SECTORS - 1))

    [ "$END" -lt "$LAST_USABLE" ] || {
        echo "Layout exceeds safe SD boundary"
        exit 1
    }

    CUR=$((END + 1))
}

# ------------------------------------------------------------
# PLAN ONLY — no destructive command before all checks finish.
# ------------------------------------------------------------

if [ "$PUBLIC" -gt 0 ]; then
    PUB_NUM="$NEXT_NUM"
    PUB_START="$CUR"

    calc_region $((PUBLIC * GIB))

    PUB_END="$END"
    NEXT_NUM=$((NEXT_NUM + 1))
fi

# Hidden metadata is always present.
META_NUM="$NEXT_NUM"
META_START="$CUR"

calc_region "$META_BYTES"

META_END="$END"
NEXT_NUM=$((NEXT_NUM + 1))

if [ "$APP" -gt 0 ]; then
    APP_NUM="$NEXT_NUM"
    APP_START="$CUR"

    calc_region $((APP * GIB))

    APP_END="$END"
    NEXT_NUM=$((NEXT_NUM + 1))
fi

if [ "$SWAP" -gt 0 ]; then
    SWAP_NUM="$NEXT_NUM"
    SWAP_START="$CUR"

    calc_region $((SWAP * GIB))

    SWAP_END="$END"
    NEXT_NUM=$((NEXT_NUM + 1))
fi

# Final geometry validation BEFORE destructive operation.
[ "$META_END" -le "$LAST_USABLE" ] || {
    echo "android_meta out of bounds"
    exit 1
}

if [ "$PUB_NUM" -gt 0 ]; then
    [ "$PUB_END" -le "$LAST_USABLE" ] || exit 1
fi

if [ "$APP_NUM" -gt 0 ]; then
    [ "$APP_END" -le "$LAST_USABLE" ] || exit 1
fi

if [ "$SWAP_NUM" -gt 0 ]; then
    [ "$SWAP_END" -le "$LAST_USABLE" ] || exit 1
fi

# ------------------------------------------------------------
# DESTRUCTIVE OPERATION STARTS HERE.
# ------------------------------------------------------------

echo "Creating Mixed SD layout:"
echo "  App    : ${APP} GiB"
echo "  Public : ${PUBLIC} GiB"
echo "  Swap   : ${SWAP} GiB"
echo "  Free   : $((TOTAL_GIB - REQUESTED_GIB)) GiB"
echo "  Meta   : 16 MiB hidden"

sgdisk --zap-all "$DEV"

# Create Public first when enabled.
if [ "$PUB_NUM" -gt 0 ]; then
    sgdisk \
        -n "${PUB_NUM}:${PUB_START}:${PUB_END}" \
        -t "${PUB_NUM}:0700" \
        -c "${PUB_NUM}:XZ1C_DOWNLOAD" \
        "$DEV"
fi

# Hidden metadata.
sgdisk \
    -n "${META_NUM}:${META_START}:${META_END}" \
    -t "${META_NUM}:19D5DF83-11B0-457B-BE2C-7559C13142A5" \
    -c "${META_NUM}:android_meta" \
    "$DEV"

# App/Internal.
if [ "$APP_NUM" -gt 0 ]; then
    sgdisk \
        -n "${APP_NUM}:${APP_START}:${APP_END}" \
        -t "${APP_NUM}:8300" \
        -c "${APP_NUM}:XZ1C_APP" \
        "$DEV"
fi

# Swap.
if [ "$SWAP_NUM" -gt 0 ]; then
    sgdisk \
        -n "${SWAP_NUM}:${SWAP_START}:${SWAP_END}" \
        -t "${SWAP_NUM}:8200" \
        -c "${SWAP_NUM}:XZ1C_SWAP" \
        "$DEV"
fi

sgdisk --print "$DEV"

if command -v partprobe >/dev/null 2>&1; then
    partprobe "$DEV" || true
fi

sleep 1

# Public/exFAT.
if [ "$PUBLIC" -gt 0 ]; then
    mkexfatfs \
        -n XZ1C_DOWNLOAD \
        "${PART_PREFIX}${PUB_NUM}"
fi

# App/F2FS.
if [ "$APP" -gt 0 ]; then
    mkfs.f2fs -f \
        "${PART_PREFIX}${APP_NUM}"
fi

# Swap.
if [ "$SWAP" -gt 0 ]; then
    mkswap \
        -L XZ1C_SWAP \
        "${PART_PREFIX}${SWAP_NUM}"
fi

echo "Mixed SD configured successfully."
echo "App=${APP} GiB"
echo "Public=${PUBLIC} GiB"
echo "Swap=${SWAP} GiB"
echo "Unallocated=$((TOTAL_GIB - REQUESTED_GIB)) GiB"
