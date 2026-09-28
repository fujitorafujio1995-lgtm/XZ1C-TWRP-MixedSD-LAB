#!/sbin/sh
set -eu

T=""
for x in /sbin/twrp /system/bin/twrp; do
    [ -x "$x" ] && T="$x" && break
done
[ -n "$T" ] || exit 1

getv() {
    "$T" get "$1" 2>/dev/null |
        sed -n 's/.*=[[:space:]]*//p' |
        tail -n 1
}

setv() {
    "$T" set "$1" "$2"
}

# ------------------------------------------------------------
# REBALANCE
# ------------------------------------------------------------

if [ "${1:-}" = "rebalance" ]; then
    MODE="${2:-}"
    W="${3:-}"

    TOTAL="$(getv tw_xz1c_sd_alloc_gib)"
    A="$(getv tw_xz1c_sd_app_gib)"
    P="$(getv tw_xz1c_sd_public_gib)"
    S="$(getv tw_xz1c_sd_swap_gib)"

    AO="$(getv tw_xz1c_sd_app_on)"
    PO="$(getv tw_xz1c_sd_public_on)"
    SO="$(getv tw_xz1c_sd_swap_on)"
    FULL="$(getv tw_xz1c_sd_full_mode)"

    case "$TOTAL" in ''|*[!0-9]*) TOTAL=0;; esac
    case "$A" in ''|*[!0-9]*) A=0;; esac
    case "$P" in ''|*[!0-9]*) P=0;; esac
    case "$S" in ''|*[!0-9]*) S=0;; esac
    case "$AO" in ''|*[!0-9]*) AO=0;; esac
    case "$PO" in ''|*[!0-9]*) PO=0;; esac
    case "$SO" in ''|*[!0-9]*) SO=0;; esac
    case "$FULL" in ''|*[!0-9]*) FULL=0;; esac

    [ "$AO" -eq 1 ] || A=0
    [ "$PO" -eq 1 ] || P=0
    [ "$SO" -eq 1 ] || S=0

    if [ "$MODE" = "value" ]; then

        # FULL MODE:
        # All three regions are enabled and currently occupy MAX.
        # Changing one region redistributes the remainder equally
        # between the other two enabled regions.
        if [ "$FULL" -eq 1 ] &&
           [ "$AO" -eq 1 ] &&
           [ "$PO" -eq 1 ] &&
           [ "$SO" -eq 1 ]; then

            case "$W" in
                app)
                    [ "$A" -le "$TOTAL" ] || A="$TOTAL"
                    R=$((TOTAL - A))
                    P=$((R / 2))
                    S=$((R - P))
                    ;;

                public)
                    [ "$P" -le "$TOTAL" ] || P="$TOTAL"
                    R=$((TOTAL - P))
                    A=$((R / 2))
                    S=$((R - A))
                    ;;

                swap)
                    [ "$S" -le "$TOTAL" ] || S="$TOTAL"
                    R=$((TOTAL - S))
                    A=$((R / 2))
                    P=$((R - A))
                    ;;
            esac

        # PARTIAL MODE:
        # Do NOT redistribute unused space.
        # The edited region can only consume currently unallocated space.
        else

            case "$W" in
                app)
                    R=$((TOTAL - P - S))
                    [ "$R" -ge 0 ] || R=0
                    [ "$A" -le "$R" ] || A="$R"
                    ;;

                public)
                    R=$((TOTAL - A - S))
                    [ "$R" -ge 0 ] || R=0
                    [ "$P" -le "$R" ] || P="$R"
                    ;;

                swap)
                    R=$((TOTAL - A - P))
                    [ "$R" -ge 0 ] || R=0
                    [ "$S" -le "$R" ] || S="$R"
                    ;;
            esac
        fi
    fi

    SUM=$((A + P + S))

    if [ "$AO" -eq 1 ] &&
       [ "$PO" -eq 1 ] &&
       [ "$SO" -eq 1 ] &&
       [ "$SUM" -eq "$TOTAL" ] &&
       [ "$TOTAL" -gt 0 ]; then
        FULL=1
    else
        FULL=0
    fi

    U=$((TOTAL - SUM))
    [ "$U" -ge 0 ] || U=0

    setv tw_xz1c_sd_app_gib "$A"
    setv tw_xz1c_sd_public_gib "$P"
    setv tw_xz1c_sd_swap_gib "$S"
    setv tw_xz1c_sd_full_mode "$FULL"
    setv tw_xz1c_sd_selected_gib "$SUM"
    setv tw_xz1c_sd_unallocated_gib "$U"
    setv tw_xz1c_sd_status \
        "Selected: ${SUM} GiB / ${TOTAL} GiB; Unallocated: ${U} GiB"

    exit 0
fi

# ------------------------------------------------------------
# LOAD / PROBE SD
# ------------------------------------------------------------

DEV="${XZ1C_SD_DEV:-/dev/block/mmcblk0}"

[ -b "$DEV" ] || {
    setv tw_xz1c_sd_loaded 0
    setv tw_xz1c_sd_status "SD card not found"
    exit 1
}

SECTOR="$(blockdev --getss "$DEV")"
BYTES="$(blockdev --getsize64 "$DEV")"

GIB=1073741824
FIRST=2048
GPT=34
META=$((16 * 1024 * 1024))

UB=$((BYTES - FIRST * SECTOR - GPT * SECTOR - META))

[ "$UB" -gt 0 ] || {
    setv tw_xz1c_sd_loaded 0
    setv tw_xz1c_sd_status "SD card is too small"
    exit 1
}

TOTAL=$((UB / GIB))
REM=$((UB % GIB))
TENTHS=$((REM * 10 / GIB))

# ------------------------------------------------------------
# DETECT EXISTING MIXEDSD LAYOUT
# ------------------------------------------------------------

LAYOUT="none"

EXIST_APP=0
EXIST_PUBLIC=0
EXIST_SWAP=0
EXIST_META=0

if command -v sgdisk >/dev/null 2>&1; then
    GPT_OUT="$(sgdisk -p "$DEV" 2>/dev/null || true)"

    if echo "$GPT_OUT" | grep -q "android_meta"; then
        EXIST_META=1
    fi

    if echo "$GPT_OUT" | grep -q "XZ1C_APP"; then
        EXIST_APP=1
    fi

    if echo "$GPT_OUT" | grep -q "XZ1C_DOWNLOAD"; then
        EXIST_PUBLIC=1
    fi

    if echo "$GPT_OUT" | grep -q "XZ1C_SWAP"; then
        EXIST_SWAP=1
    fi

    if [ "$EXIST_META" -eq 1 ] &&
       { [ "$EXIST_APP" -eq 1 ] ||
         [ "$EXIST_PUBLIC" -eq 1 ] ||
         [ "$EXIST_SWAP" -eq 1 ]; }; then
        LAYOUT="mixed"
    fi
fi

# ------------------------------------------------------------
# READ EXISTING MIXEDSD SIZES
# ------------------------------------------------------------

if [ "$LAYOUT" = "mixed" ]; then

    APP=0
    PUB=0
    SWAP=0

    # Read partition sizes in sectors from sgdisk output.
    if [ "$EXIST_APP" -eq 1 ]; then
        APP_SECTORS="$(
            echo "$GPT_OUT" |
            awk '$0 ~ /XZ1C_APP/ {print ($3 - $2 + 1); exit}'
        )"
        case "$APP_SECTORS" in
            ''|*[!0-9]*) APP_SECTORS=0;;
        esac
        APP=$((APP_SECTORS * SECTOR / GIB))
    fi

    if [ "$EXIST_PUBLIC" -eq 1 ]; then
        PUB_SECTORS="$(
            echo "$GPT_OUT" |
            awk '$0 ~ /XZ1C_DOWNLOAD/ {print ($3 - $2 + 1); exit}'
        )"
        case "$PUB_SECTORS" in
            ''|*[!0-9]*) PUB_SECTORS=0;;
        esac
        PUB=$((PUB_SECTORS * SECTOR / GIB))
    fi

    if [ "$EXIST_SWAP" -eq 1 ]; then
        SWAP_SECTORS="$(
            echo "$GPT_OUT" |
            awk '$0 ~ /XZ1C_SWAP/ {print ($3 - $2 + 1); exit}'
        )"
        case "$SWAP_SECTORS" in
            ''|*[!0-9]*) SWAP_SECTORS=0;;
        esac
        SWAP=$((SWAP_SECTORS * SECTOR / GIB))
    fi

    # Enabled state follows actual partitions.
    [ "$EXIST_APP" -eq 1 ] &&
        APP_ON=1 ||
        APP_ON=0

    [ "$EXIST_PUBLIC" -eq 1 ] &&
        PUBLIC_ON=1 ||
        PUBLIC_ON=0

    [ "$EXIST_SWAP" -eq 1 ] &&
        SWAP_ON=1 ||
        SWAP_ON=0

    SUM=$((APP + PUB + SWAP))

    [ "$SUM" -le "$TOTAL" ] || {
        APP=0
        PUB=0
        SWAP=0
        APP_ON=1
        PUBLIC_ON=1
        SWAP_ON=0
        SUM=0
        LAYOUT="none"
    }

else

    # No existing MixedSD layout.
    # Only here do we create the initial 60/40/0 defaults.
    APP=$((TOTAL * 60 / 100))
    PUB=$((TOTAL - APP))
    SWAP=0

    APP_ON=1
    PUBLIC_ON=1
    SWAP_ON=0

    SUM=$((APP + PUB + SWAP))
fi

U=$((TOTAL - SUM))
[ "$U" -ge 0 ] || U=0

# Existing layout that already fills the allocation is full mode,
# but only when all three regions actually exist.
if [ "$APP_ON" -eq 1 ] &&
   [ "$PUBLIC_ON" -eq 1 ] &&
   [ "$SWAP_ON" -eq 1 ] &&
   [ "$SUM" -eq "$TOTAL" ] &&
   [ "$TOTAL" -gt 0 ]; then
    FULL=1
else
    FULL=0
fi

# ------------------------------------------------------------
# UPDATE TWRP VARIABLES
# ------------------------------------------------------------

setv tw_xz1c_sd_loaded 1
setv tw_xz1c_sd_total_gib "$TOTAL"
setv tw_xz1c_sd_total_display "${TOTAL}.${TENTHS} GiB"
setv tw_xz1c_sd_alloc_gib "$TOTAL"

setv tw_xz1c_sd_device "$DEV"
setv tw_xz1c_sd_sector "$SECTOR"
setv tw_xz1c_sd_bytes "$BYTES"
setv tw_xz1c_sd_layout "$LAYOUT"

setv tw_xz1c_sd_app_gib "$APP"
setv tw_xz1c_sd_public_gib "$PUB"
setv tw_xz1c_sd_swap_gib "$SWAP"

setv tw_xz1c_sd_app_on "$APP_ON"
setv tw_xz1c_sd_public_on "$PUBLIC_ON"
setv tw_xz1c_sd_swap_on "$SWAP_ON"

setv tw_xz1c_sd_full_mode "$FULL"
setv tw_xz1c_sd_selected_gib "$SUM"
setv tw_xz1c_sd_unallocated_gib "$U"

if [ "$LAYOUT" = "mixed" ]; then
    setv tw_xz1c_sd_status \
        "Mixed SD detected: ${SUM} GiB selected; ${U} GiB unallocated"
else
    setv tw_xz1c_sd_status \
        "SD loaded: ${TOTAL}.${TENTHS} GiB usable allocation"
fi

echo "Capacity: ${TOTAL}.${TENTHS} GiB usable"
echo "Layout: $LAYOUT"
echo "App: ${APP} GiB"
echo "Public: ${PUB} GiB"
echo "Swap: ${SWAP} GiB"
echo "Unallocated: ${U} GiB"
