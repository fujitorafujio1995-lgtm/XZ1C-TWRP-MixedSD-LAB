#!/usr/bin/env bash
set -euo pipefail

MAGISKBOOT="${1:?usage: patch_image.sh MAGISKBOOT BASE_IMAGE OUT ROOT_DIR}"
IMAGE="${2:?usage: patch_image.sh MAGISKBOOT BASE_IMAGE OUT ROOT_DIR}"
OUT="${3:?usage: patch_image.sh MAGISKBOOT BASE_IMAGE OUT ROOT_DIR}"
ROOT_DIR="${4:?usage: patch_image.sh MAGISKBOOT BASE_IMAGE OUT ROOT_DIR}"

EXPECTED="260e8a41cd1e58d19b199bb0bf04aeef6ad63739dc31c8170f5bd474c0191a1a"

[ -x "$MAGISKBOOT" ] || {
    echo "ERROR: magiskboot not executable: $MAGISKBOOT"
    exit 1
}

[ -f "$IMAGE" ] || {
    echo "ERROR: base image not found: $IMAGE"
    exit 1
}

HASH="$(sha256sum "$IMAGE" | awk '{print $1}')"

[ "$HASH" = "$EXPECTED" ] || {
    echo "ERROR: base SHA256 mismatch"
    echo "Expected: $EXPECTED"
    echo "Actual:   $HASH"
    exit 1
}

command -v python3 >/dev/null 2>&1 || {
    echo "ERROR: python3 not found"
    exit 1
}

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

mkdir -p "$T/edit"

cd "$T"

echo "[1/5] magiskboot unpack"
"$MAGISKBOOT" unpack "$IMAGE"

[ -f ramdisk.cpio ] || {
    echo "ERROR: magiskboot did not produce ramdisk.cpio"
    exit 1
}

echo "[2/5] patch TWRP XML"

"$MAGISKBOOT" cpio ramdisk.cpio test >/dev/null 2>&1 || true

"$MAGISKBOOT" cpio ramdisk.cpio \
    "extract twres/portrait.xml $T/edit/portrait.xml"

"$MAGISKBOOT" cpio ramdisk.cpio \
    "extract twres/ui.xml $T/edit/ui.xml" || true

python3 "$ROOT_DIR/patches/patch_portrait.py" \
    "$T/edit/portrait.xml" \
    "$T/edit/ui.xml"

"$MAGISKBOOT" cpio ramdisk.cpio \
    "add 0644 twres/portrait.xml $T/edit/portrait.xml"

if [ -f "$T/edit/ui.xml" ]; then
    "$MAGISKBOOT" cpio ramdisk.cpio \
        "add 0644 twres/ui.xml $T/edit/ui.xml"
fi

echo "[3/5] add MixedSD scripts"

for script in \
    xz1c_mixed_sd_format.sh \
    xz1c_mixed_sd_inspect.sh \
    xz1c_mixed_sd_partition.sh \
    xz1c_mixed_sd_preflight.sh \
    xz1c_mixed_sd_probe.sh \
    xz1c_mixed_sd_use_internal.sh \
    runatboot.sh \
    xz1c_twrp_restore_theme.sh
do
    [ -f "$ROOT_DIR/scripts/$script" ] || {
        echo "ERROR: missing script: $ROOT_DIR/scripts/$script"
        exit 1
    }

    "$MAGISKBOOT" cpio ramdisk.cpio \
        "add 0755 system/bin/$script $ROOT_DIR/scripts/$script"
done

echo "[4/5] magiskboot repack"

"$MAGISKBOOT" repack "$IMAGE" "$T/new-boot.img"

[ -s "$T/new-boot.img" ] || {
    echo "ERROR: magiskboot repack produced no image"
    exit 1
}

cp "$T/new-boot.img" "$OUT"

echo "[5/5] verify output"

file "$OUT"
sha256sum "$OUT"

echo
echo "SUCCESS"
echo "Output: $OUT"
