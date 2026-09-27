#!/bin/bash
set -euo pipefail

MAGISKBOOT="$1"
IMAGE="$2"
OUT="$3"
ROOT_DIR="$4"

mkdir -p "$OUT" work
cd work
rm -f kernel ramdisk.cpio second dtb extra recovery_dtbo header new-boot.img

"$MAGISKBOOT" unpack "$IMAGE"
"$MAGISKBOOT" cpio ramdisk.cpio test >/dev/null || true

mkdir -p edit
"$MAGISKBOOT" cpio ramdisk.cpio "extract twres/portrait.xml edit/portrait.xml"
python3 "$ROOT_DIR/patches/patch_portrait.py" edit/portrait.xml
"$MAGISKBOOT" cpio ramdisk.cpio "add 0644 twres/portrait.xml edit/portrait.xml"

"$MAGISKBOOT" cpio ramdisk.cpio "add 0755 system/bin/xz1c_mixed_sd_inspect.sh $ROOT_DIR/scripts/xz1c_mixed_sd_inspect.sh"

"$MAGISKBOOT" repack "$IMAGE" new-boot.img
cp new-boot.img "$OUT/XZ1C-TWRP-MixedSD-v1-LAB.img"
sha256sum "$OUT/XZ1C-TWRP-MixedSD-v1-LAB.img" | tee "$OUT/XZ1C-TWRP-MixedSD-v1-LAB.img.sha256"
