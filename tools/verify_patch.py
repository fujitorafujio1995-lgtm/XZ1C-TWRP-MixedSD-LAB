#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

p = (ROOT / "patches/patch_portrait.py").read_text()
s = (ROOT / "scripts/xz1c_mixed_sd_partition.sh").read_text()
probe = (ROOT / "scripts/xz1c_mixed_sd_probe.sh").read_text()

# ------------------------------------------------------------
# Python syntax
# ------------------------------------------------------------
compile(p, "patch_portrait.py", "exec")

# ------------------------------------------------------------
# Required UI
# ------------------------------------------------------------
for marker in (
    "Partition the memory card",
    "Load SD",
    "Configure Mixed SD",
    "Format SD",
    "Back",

    # Three user-controlled regions
    "tw_xz1c_sd_app_gib",
    "tw_xz1c_sd_public_gib",
    "tw_xz1c_sd_swap_gib",

    # Enable/disable state
    "tw_xz1c_sd_app_on",
    "tw_xz1c_sd_public_on",
    "tw_xz1c_sd_swap_on",

    # Region labels
    "App / Internal",
    "Download / Public",
    "Swap",

    # Filesystems
    "F2FS",
    "exFAT",
    "Linux swap",
):
    assert marker in p, f"missing UI marker: {marker}"

# ------------------------------------------------------------
# Three checkbox controls
# ------------------------------------------------------------
for marker in (
    "[✓] App / Internal",
    "[✓] Download / Public",
    "[ ] Swap",
):
    assert marker in p, f"missing checkbox marker: {marker}"

# ------------------------------------------------------------
# Zero is allowed for disabled regions
# ------------------------------------------------------------
for marker in (
    'data variable="tw_xz1c_sd_app_gib" min="0"',
    'data variable="tw_xz1c_sd_public_gib" min="0"',
    'data variable="tw_xz1c_sd_swap_gib" min="0"',
):
    assert marker in p, f"zero-capable region missing: {marker}"

assert "Each region must be at least 1 GiB" not in s
assert 'ge 1' not in s

# ------------------------------------------------------------
# All three values participate in the final partition command
# ------------------------------------------------------------
assert (
    "tw_action_param=%tw_xz1c_sd_app_gib% "
    "%tw_xz1c_sd_public_gib% "
    "%tw_xz1c_sd_swap_gib% f2fs"
) in p, "partition action does not receive all three regions"

# ------------------------------------------------------------
# Hidden android_meta
# ------------------------------------------------------------
assert "android_meta" in s
assert "16 * 1024 * 1024" in s

# ------------------------------------------------------------
# Destructive-operation safety
# Every required command check must occur BEFORE zap-all.
# ------------------------------------------------------------
zap = s.find('sgdisk --zap-all "$DEV"')
assert zap >= 0, "missing destructive GPT wipe"

for required in (
    'command -v sgdisk',
    'command -v mkexfatfs',
    'command -v mkfs.f2fs',
    'command -v mkswap',
):
    pos = s.find(required)
    assert pos >= 0, f"missing prerequisite check: {required}"
    assert pos < zap, f"prerequisite check occurs after wipe: {required}"

# ------------------------------------------------------------
# Probe -> TWRP variables
# ------------------------------------------------------------
for marker in (
    "tw_xz1c_sd_alloc_gib",
    "tw_xz1c_sd_app_gib",
    "tw_xz1c_sd_public_gib",
    "tw_xz1c_sd_swap_gib",
):
    assert marker in probe, f"probe missing variable: {marker}"

# ------------------------------------------------------------
# No old two-region variables
# ------------------------------------------------------------
for marker in (
    "tw_xz1c_internal_gib",
    "tw_xz1c_portable_gib",
):
    assert marker not in p, f"old two-region variable remains: {marker}"

print("PASS")
print(" - Python syntax")
print(" - MixedSD UI markers")
print(" - 3 region variables")
print(" - checkbox markers")
print(" - zero-capable regions")
print(" - hidden android_meta")
print(" - destructive-operation ordering")
print(" - probe/TWRP variables")
print(" - old 2-region variables removed")
