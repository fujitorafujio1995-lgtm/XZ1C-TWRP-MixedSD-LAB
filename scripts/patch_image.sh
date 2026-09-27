#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BASE="${1:-/storage/emulated/0/Download/XZ1C-TWRP-MixedSD-LAB/base/twrp-3.7.1_12-0-20250728-lilac.img}"
OUT="${2:-XZ1C-TWRP-MixedSD-v2.4-LAB.img}"

EXPECTED="260e8a41cd1e58d19b199bb0bf04aeef6ad63739dc31c8170f5bd474c0191a1a"

[ -f "$BASE" ] || {
    echo "ERROR: base image not found"
    exit 1
}

HASH="$(sha256sum "$BASE" | awk '{print $1}')"

[ "$HASH" = "$EXPECTED" ] || {
    echo "ERROR: base SHA256 mismatch"
    echo "Expected: $EXPECTED"
    echo "Actual:   $HASH"
    exit 1
}

command -v cpio >/dev/null 2>&1 || {
    echo "ERROR: cpio not found"
    exit 1
}

command -v gzip >/dev/null 2>&1 || {
    echo "ERROR: gzip not found"
    exit 1
}

command -v python3 >/dev/null 2>&1 || {
    echo "ERROR: python3 not found"
    exit 1
}

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

mkdir -p "$T/ramdisk"

echo "[1/7] Reading Android boot header..."

python3 - "$BASE" "$T/header.txt" <<'PY'
import struct
import sys

img = sys.argv[1]
out = sys.argv[2]

with open(img, "rb") as f:
    h = f.read(4096)

if h[:8] != b"ANDROID!":
    raise SystemExit("Invalid Android boot image")

u32 = lambda o: struct.unpack_from("<I", h, o)[0]

kernel_size  = u32(8)
kernel_addr  = u32(12)
ramdisk_size = u32(16)
ramdisk_addr = u32(20)
second_size  = u32(24)
second_addr  = u32(28)
tags_addr    = u32(32)
page_size    = u32(36)
dt_size      = u32(40)

cmdline = h[64:576].split(b"\0", 1)[0].decode(
    "utf-8", errors="replace"
)

with open(out, "w") as f:
    f.write(f"kernel_size={kernel_size}\n")
    f.write(f"kernel_addr={kernel_addr}\n")
    f.write(f"ramdisk_size={ramdisk_size}\n")
    f.write(f"ramdisk_addr={ramdisk_addr}\n")
    f.write(f"second_size={second_size}\n")
    f.write(f"second_addr={second_addr}\n")
    f.write(f"tags_addr={tags_addr}\n")
    f.write(f"page_size={page_size}\n")
    f.write(f"dt_size={dt_size}\n")
    f.write("cmdline=" + cmdline + "\n")

print("header v0")
print("kernel_size =", kernel_size)
print("kernel_addr =", hex(kernel_addr))
print("ramdisk_size =", ramdisk_size)
print("ramdisk_addr =", hex(ramdisk_addr))
print("second_size =", second_size)
print("tags_addr =", hex(tags_addr))
print("page_size =", page_size)
print("dt_size =", dt_size)
print("cmdline =", cmdline)
PY

KERNEL_SIZE="$(sed -n 's/^kernel_size=//p' "$T/header.txt")"
KERNEL_ADDR="$(sed -n 's/^kernel_addr=//p' "$T/header.txt")"
RAMDISK_SIZE="$(sed -n 's/^ramdisk_size=//p' "$T/header.txt")"
RAMDISK_ADDR="$(sed -n 's/^ramdisk_addr=//p' "$T/header.txt")"
SECOND_SIZE="$(sed -n 's/^second_size=//p' "$T/header.txt")"
SECOND_ADDR="$(sed -n 's/^second_addr=//p' "$T/header.txt")"
TAGS_ADDR="$(sed -n 's/^tags_addr=//p' "$T/header.txt")"
PAGE_SIZE="$(sed -n 's/^page_size=//p' "$T/header.txt")"
DT_SIZE="$(sed -n 's/^dt_size=//p' "$T/header.txt")"
CMDLINE="$(sed -n 's/^cmdline=//p' "$T/header.txt")"

echo "[2/7] Extracting kernel..."

dd if="$BASE" \
   of="$T/kernel" \
   bs="$PAGE_SIZE" \
   skip=1 \
   count=$(( (KERNEL_SIZE + PAGE_SIZE - 1) / PAGE_SIZE )) \
   status=none

echo "[3/7] Extracting ramdisk..."

RAMDISK_PAGE=$(( (KERNEL_SIZE + PAGE_SIZE - 1) / PAGE_SIZE + 1 ))

dd if="$BASE" \
   of="$T/ramdisk.cpio.gz" \
   bs="$PAGE_SIZE" \
   skip="$RAMDISK_PAGE" \
   count=$(( (RAMDISK_SIZE + PAGE_SIZE - 1) / PAGE_SIZE )) \
   status=none

echo "[4/7] Unpacking ramdisk..."

gzip -dc "$T/ramdisk.cpio.gz" > "$T/ramdisk.cpio"

(
    cd "$T/ramdisk"
    cpio -idm --no-absolute-filenames < "$T/ramdisk.cpio"
)

echo "[5/7] Applying TWRP patch..."

python3 patches/patch_portrait.py \
    "$T/ramdisk/twres/portrait.xml" \
    "$T/ramdisk/twres/ui.xml"

install -m 0755 scripts/xz1c_mixed_sd_*.sh "$T/ramdisk/sbin/"
install -m 0755 scripts/runatboot.sh "$T/ramdisk/sbin/"
install -m 0755 scripts/xz1c_twrp_restore_theme.sh "$T/ramdisk/sbin/"

echo "[6/7] Repacking ramdisk..."

(
    cd "$T/ramdisk"
    find . -print0 | cpio --null -o -H newc
) > "$T/new.cpio"

gzip -9 -c "$T/new.cpio" > "$T/newramdisk.cpio.gz"

NEW_RAMDISK_SIZE="$(stat -c '%s' "$T/newramdisk.cpio.gz")"

echo "Original ramdisk: $RAMDISK_SIZE"
echo "New ramdisk:      $NEW_RAMDISK_SIZE"

echo "[7/7] Building Android boot image..."

python3 - "$T/kernel" "$T/newramdisk.cpio.gz" "$OUT" \
    "$KERNEL_ADDR" "$RAMDISK_ADDR" "$SECOND_SIZE" "$SECOND_ADDR" \
    "$TAGS_ADDR" "$PAGE_SIZE" "$CMDLINE" "$BASE" <<'PY'
import struct
import sys

kernel_path = sys.argv[1]
ramdisk_path = sys.argv[2]
out_path = sys.argv[3]

kernel_addr = int(sys.argv[4])
ramdisk_addr = int(sys.argv[5])
second_size = int(sys.argv[6])
second_addr = int(sys.argv[7])
tags_addr = int(sys.argv[8])
page_size = int(sys.argv[9])
cmdline = sys.argv[10].encode()

def pad(data, n):
    return data + b"\0" * ((n - len(data) % n) % n)

with open(kernel_path, "rb") as f:
    kernel = f.read()

with open(ramdisk_path, "rb") as f:
    ramdisk = f.read()

if len(cmdline) > 511:
    raise SystemExit("cmdline exceeds Android boot v0 limit")

header = bytearray(608)

header[0:8] = b"ANDROID!"

struct.pack_into("<I", header, 8,  len(kernel))
struct.pack_into("<I", header, 12, kernel_addr)
struct.pack_into("<I", header, 16, len(ramdisk))
struct.pack_into("<I", header, 20, ramdisk_addr)
struct.pack_into("<I", header, 24, second_size)
struct.pack_into("<I", header, 28, second_addr)
struct.pack_into("<I", header, 32, tags_addr)
struct.pack_into("<I", header, 36, page_size)
struct.pack_into("<I", header, 40, 0)

header[64:64+len(cmdline)] = cmdline

# Header v0 uses a 16-byte image name at offset 48.
# The original image has an empty name.
header[48:64] = b"\0" * 16

# Preserve the original boot-image ID field.
with open(sys.argv[11], "rb") as f:
    original_header = f.read(608)

header[576:608] = original_header[576:608]

with open(out_path, "wb") as f:
    f.write(pad(header, page_size))
    f.write(pad(kernel, page_size))
    f.write(pad(ramdisk, page_size))

print("Wrote:", out_path)
print("Size:", len(open(out_path, "rb").read()))
PY

echo
echo "SUCCESS"
echo "Output: $OUT"
echo "SHA256:"
sha256sum "$OUT"
