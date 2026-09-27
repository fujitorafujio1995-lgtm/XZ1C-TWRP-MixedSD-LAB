#!/system/bin/sh
set -eu

DEV="${XZ1C_SD_DEV:-/dev/block/mmcblk0}"

APP="${1:-}"
PUBLIC="${2:-}"
SWAP="${3:-}"
FS="${4:-f2fs}"

[ -b "$DEV" ] || {
    echo "SD block device not found: $DEV"
    exit 1
}

[ -n "$APP" ] && [ -n "$PUBLIC" ] && [ -n "$SWAP" ] || {
    echo "Missing region sizes"
    exit 1
}

[ "$FS" = "f2fs" ] || {
    echo "App/Internal filesystem is fixed to F2FS"
    exit 1
}

case "$APP:$PUBLIC:$SWAP" in
    *[!0-9:]*)
        echo "Region sizes must be non-negative integers"
        exit 1
        ;;
esac

SECTOR="$(blockdev --getss "$DEV")"
BYTES="$(blockdev --getsize64 "$DEV")"
SECTORS="$(blockdev --getsz "$DEV")"

[ "$SECTOR" -eq 512 ] || {
    echo "Unexpected sector size: $SECTOR"
    exit 1
}

TOTAL_GIB=$((BYTES / 1073741824))
REQUESTED_GIB=$((APP + PUBLIC + SWAP))

# The three user-controlled regions must consume the complete
# allocation reported by the probe.
[ "$REQUESTED_GIB" -eq "$TOTAL_GIB" ] || {
    echo "Region total must equal usable allocation"
    echo "Requested: ${REQUESTED_GIB} GiB"
    echo "Capacity:  ${TOTAL_GIB} GiB"
    exit 1
}

# At least one user region must be enabled.
[ "$APP" -gt 0 ] || [ "$PUBLIC" -gt 0 ] || [ "$SWAP" -gt 0 ] || {
    echo "At least one region must be enabled"
    exit 1
}

META_BYTES=$((16 * 1024 * 1024))
META_SECTORS=$((META_BYTES / SECTOR))

FIRST=2048
GPT_RESERVED=34
LAST_USABLE=$((SECTORS - GPT_RESERVED - 1))

PUBLIC_SECTORS=$((PUBLIC * 1073741824 / SECTOR))
APP_SECTORS=$((APP * 1073741824 / SECTOR))
SWAP_SECTORS=$((SWAP * 1073741824 / SECTOR))

# Check required programs BEFORE any destructive command.
command -v sgdisk >/dev/null 2>&1 || {
    echo "sgdisk missing"
    exit 1
}

if [ "$PUBLIC" -gt 0 ]; then
    command -v mkexfatfs >/dev/null 2>&1 || {
        echo "mkexfatfs missing"
        exit 1
    }
fi

if [ "$APP" -gt 0 ]; then
    command -v mkfs.f2fs >/dev/null 2>&1 || {
        echo "mkfs.f2fs missing"
        exit 1
    }
fi

if [ "$SWAP" -gt 0 ]; then
    command -v mkswap >/dev/null 2>&1 || {
        echo "mkswap missing"
        exit 1
    }
fi

# Build sector layout.
#
# P1 = Public/exFAT when enabled
# P2 = hidden android_meta, always 16 MiB
# P3 = App/Internal F2FS when enabled
# P4 = Swap when enabled
#
# Disabled user regions are simply omitted.

P=1
if [ "$PUBLIC" -gt 0 ]; then
    P1_START="$FIRST"
    P1_END=$((P1_START + PUBLIC_SECTORS - 1))
    P=$((P + 1))
else
    P1_START=0
    P1_END=0
fi

META_NUM="$P"
P2_START=$(( ${P1_END:-$((FIRST - 1))} + 1 ))
P2_END=$((P2_START + META_SECTORS - 1))
P=$((P + 1))

if [ "$APP" -gt 0 ]; then
    APP_NUM="$P"
    APP_START=$((P2_END + 1))
    APP_END=$((APP_START + APP_SECTORS - 1))
    P=$((P + 1))
else
    APP_NUM=0
    APP_START=0
    APP_END=0
fi

if [ "$SWAP" -gt 0 ]; then
    SWAP_NUM="$P"
    SWAP_START=$((P2_END + 1))
    if [ "$APP" -gt 0 ]; then
        SWAP_START=$((APP_END + 1))
    fi
    SWAP_END=$((SWAP_START + SWAP_SECTORS - 1))
else
    SWAP_NUM=0
    SWAP_START=0
    SWAP_END=0
fi

# Validate final layout BEFORE wiping.
LAST=0
if [ "$PUBLIC" -gt 0 ]; then
    LAST="$P1_END"
fi
if [ "$APP" -gt 0 ]; then
    LAST="$APP_END"
fi
if [ "$SWAP" -gt 0 ]; then
    LAST="$SWAP_END"
fi

[ "$LAST" -le "$LAST_USABLE" ] || {
    echo "GPT layout does not fit"
    exit 1
}

# -------- destructive section begins here --------

sgdisk --zap-all "$DEV"

if [ "$PUBLIC" -gt 0 ]; then
    sgdisk \
        --new=1:${P1_START}:${P1_END} \
        --typecode=1:EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 \
        --change-name=1:XZ1C_DOWNLOAD \
        "$DEV"
fi

sgdisk \
    --new=${META_NUM}:${P2_START}:${P2_END} \
    --typecode=${META_NUM}:19A710A2-B3CA-11E4-B026-10604B889DCF \
    --change-name=${META_NUM}:android_meta \
    "$DEV"

if [ "$APP" -gt 0 ]; then
    sgdisk \
        --new=${APP_NUM}:${APP_START}:${APP_END} \
        --typecode=${APP_NUM}:193D1EA4-B3CA-11E4-B075-10604B889DCF \
        --change-name=${APP_NUM}:android_ext \
        "$DEV"
fi

if [ "$SWAP" -gt 0 ]; then
    sgdisk \
        --new=${SWAP_NUM}:${SWAP_START}:${SWAP_END} \
        --typecode=${SWAP_NUM}:0657FD6D-A4AB-43C4-84E5-0933C84B4F4F \
        --change-name=${SWAP_NUM}:XZ1C_SWAP \
        "$DEV"
fi

sgdisk --randomize-guids "$DEV"
sgdisk --verify "$DEV"

# Format only enabled regions.
if [ "$PUBLIC" -gt 0 ]; then
    mkexfatfs -n XZ1C_DOWNLOAD "${DEV}1"
fi

if [ "$APP" -gt 0 ]; then
    mkfs.f2fs -f "${DEV}${APP_NUM}"
fi

if [ "$SWAP" -gt 0 ]; then
    mkswap -L XZ1C_SWAP "${DEV}${SWAP_NUM}"
fi

sync

echo "Mixed SD created:"
echo "Public: ${PUBLIC} GiB"
echo "App/Internal: ${APP} GiB"
echo "Swap: ${SWAP} GiB"
echo "android_meta: 16 MiB"
