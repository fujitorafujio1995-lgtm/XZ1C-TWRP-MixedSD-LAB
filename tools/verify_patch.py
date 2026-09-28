#!/usr/bin/env python3

from pathlib import Path
import re
import sys

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")

portrait = ROOT / "patches" / "patch_portrait.py"
partition = ROOT / "scripts" / "xz1c_mixed_sd_partition.sh"
probe = ROOT / "scripts" / "xz1c_mixed_sd_probe.sh"
readme = ROOT / "PATCH_README.md"

p = portrait.read_text()
s = partition.read_text()
q = probe.read_text()
r = readme.read_text()

failed = []


def C(name, ok):
    if ok:
        print(f"OK    {name}")
    else:
        print(f"FAIL  {name}")
        failed.append(name)


def compact_shell(x):
    """
    Normalize shell source for semantic-ish string checks.
    This intentionally does NOT alter the actual source file.
    """
    x = re.sub(r"#.*", "", x)

    # Collapse all whitespace.
    x = re.sub(r"\s+", " ", x)

    # Normalize spaces inside arithmetic expansions:
    # $((TOTAL - P - S)) -> $((TOTAL-P-S))
    def arithmetic(m):
        body = re.sub(r"\s+", "", m.group(1))
        return "$((" + body + "))"

    x = re.sub(r"\$\(\((.*?)\)\)", arithmetic, x)

    # Normalize spaces around common shell operators.
    x = re.sub(r"\[\s+", "[ ", x)
    x = re.sub(r"\s+\]", " ]", x)

    return x


Q = compact_shell(q)
S = compact_shell(s)
P = compact_shell(p)


# ------------------------------------------------------------
# UI / XML
# ------------------------------------------------------------

C(
    "stock partsdcard page",
    'name="partsdcard"' in p and
    'name="partsdcardsel"' not in p.replace(
        '<page name="partsdcardsel">',
        '',
        1
    )
)

C(
    "stock Select Storage flow",
    'partsdcardsel' in p
)

C(
    "old Advanced entry removed",
    "Partition the memory card" not in p
)

C(
    "old custom pages removed",
    all(
        f'name="{x}"' not in p
        for x in (
            "xz1c_sd_menu",
            "xz1c_sd_config",
            "xz1c_sd_format",
        )
    )
)

C("F2FS App/Internal", "App / Internal (F2FS)" in p)
C("exFAT Download/Public", "Download / Public (exFAT)" in p)
C("Linux swap", "Swap:" in p)

C(
    "checkbox controls",
    'style="checkbox"' in p
)

C(
    "checkbox true",
    'image resource="checkbox_true"' in p
)

C(
    "checkbox false",
    'image resource="checkbox_false"' in p
)


# ------------------------------------------------------------
# Variables
# ------------------------------------------------------------

for name in (
    "tw_xz1c_sd_app_gib",
    "tw_xz1c_sd_public_gib",
    "tw_xz1c_sd_swap_gib",
    "tw_xz1c_sd_app_on",
    "tw_xz1c_sd_public_on",
    "tw_xz1c_sd_swap_on",
    "tw_xz1c_sd_full_mode",
    "tw_xz1c_sd_selected_gib",
    "tw_xz1c_sd_unallocated_gib",
):
    C(
        f"variable {name}",
        f'name="{name}"' in p
    )


# ------------------------------------------------------------
# Hidden android_meta / no fourth user region
# ------------------------------------------------------------

C(
    "android_meta hidden from UI",
    "android_meta" not in re.sub(
        r'<variable.*?>',
        '',
        p
    )
    or 'text>android_meta' not in p
)

C(
    "android_meta backend",
    "android_meta" in s and
    "19D5DF83-11B0-457B-BE2C-7559C13142A5" in s
)

C(
    "no fourth user region",
    all(
        x not in p
        for x in (
            "Region 4",
            "Fourth region",
            "fourth region",
            "android_meta size",
        )
    )
)


# ------------------------------------------------------------
# Partition allocation rules
# ------------------------------------------------------------

C(
    "sum <= max",
    (
        "REQUESTED_GIB=$((APP + PUBLIC + SWAP))" in s
        or "REQUESTED_GIB=$((APP+PUBLIC+SWAP))" in S
    )
    and '"$REQUESTED_GIB" -le "$TOTAL_GIB"' in s
)

C(
    "sum above max rejected",
    'Requested ${REQUESTED_GIB} GiB exceeds usable ${TOTAL_GIB} GiB' in s
    and '"$REQUESTED_GIB" -le "$TOTAL_GIB"' in s
)

C(
    "unallocated calculated",
    (
        'TOTAL_GIB - REQUESTED_GIB' in s
        or 'TOTAL_GIB-REQUESTED_GIB' in S
    )
    and 'Unallocated=' in s
)


# ------------------------------------------------------------
# Partial mode
# ------------------------------------------------------------

C(
    "partial mode",
    "R=$((TOTAL-P-S))" in Q and
    "R=$((TOTAL-A-S))" in Q and
    "R=$((TOTAL-A-P))" in Q
)


# ------------------------------------------------------------
# Full mode
# ------------------------------------------------------------

C(
    "full mode requires all three",
    all(
        x in Q
        for x in (
            '[ "$FULL" -eq 1 ]',
            '[ "$AO" -eq 1 ]',
            '[ "$PO" -eq 1 ]',
            '[ "$SO" -eq 1 ]',
        )
    )
)

C(
    "full mode requires total",
    '[ "$SUM" -eq "$TOTAL" ]' in Q
)

C(
    "full App redistribution",
    "R=$((TOTAL-A))" in Q and
    "P=$((R/2))" in Q and
    "S=$((R-P))" in Q
)

C(
    "full Public redistribution",
    "R=$((TOTAL-P))" in Q and
    "A=$((R/2))" in Q and
    "S=$((R-A))" in Q
)

C(
    "full Swap redistribution",
    "R=$((TOTAL-S))" in Q and
    "A=$((R/2))" in Q and
    "P=$((R-A))" in Q
)


# ------------------------------------------------------------
# Disabled regions
# ------------------------------------------------------------

C(
    "disabled App = 0",
    '[ "$AO" -eq 1 ] || A=0' in Q
)

C(
    "disabled Public = 0",
    '[ "$PO" -eq 1 ] || P=0' in Q
)

C(
    "disabled Swap = 0",
    '[ "$SO" -eq 1 ] || S=0' in Q
)


# ------------------------------------------------------------
# Safety / geometry
# ------------------------------------------------------------

C(
    "zero configuration rejected",
    '"Enable at least one region"' in s
)

C(
    "geometry before zap",
    s.find("FINAL geometry validation") < s.find("sgdisk --zap-all")
)

C(
    "hidden metadata 16 MiB",
    "META_BYTES=$((16 * 1024 * 1024))" in s
)

C(
    "dynamic partition numbers",
    "PUB_NUM" in s and
    "META_NUM" in s and
    "APP_NUM" in s and
    "SWAP_NUM" in s
)


# ------------------------------------------------------------
# Rebalance helper
# ------------------------------------------------------------

C(
    "rebalance in existing probe",
    'if [ "${1:-}" = "rebalance" ]' in q
    or 'if [ "${1:-}" = rebalance ]' in q
)

C(
    "UI calls existing probe",
    "/sbin/xz1c_mixed_sd_probe.sh rebalance" in p
)


# ------------------------------------------------------------
# Confirmations
# ------------------------------------------------------------

C(
    "Configure confirmation",
    "Configure Mixed SD" in p and
    "confirm_action" in p
)

C(
    "Format confirmation",
    "Format SD" in p and
    "confirm_action" in p
)


# ------------------------------------------------------------
# Result
# ------------------------------------------------------------

if failed:
    print()
    print("Failed checks:")
    for x in failed:
        print(f" - {x}")
    raise SystemExit(1)

print()
print("PASS — MixedSD v6 verifier")
