# XZ1C TWRP Mixed SD LAB

Binary-derived reconstruction project for the Sony Xperia XZ1 Compact (lilac).

## Base recovery

- TWRP: `3.7.1_12-0-20250728-lilac`
- Base image: `base/twrp-3.7.1_12-0-20250728-lilac.img`
- Base SHA-256: `260e8a41cd1e58d19b199bb0bf04aeef6ad63739dc31c8170f5bd474c0191a1a`

This is **not** a recreation of the original TWRP C/C++ source tree. We only have the compiled recovery image, so this repository keeps that image as the golden base and applies controlled ramdisk/TWRP-resource modifications.

## Milestone 1: non-destructive UI prototype

The first build adds an `XZ1C Mixed Adoptable SD (LAB)` entry to the existing Advanced menu. It opens an inspection page and runs a read-only SD/GPT diagnostic. It does **not** repartition, format, wipe, or modify the SD card.

The destructive mixed-storage backend is intentionally not included yet. Before implementing that part we need to reproduce the Android 15 ROM's vold-compatible adopted-storage metadata flow.

## GitHub Actions

Workflow: `.github/workflows/build.yml`

- `workflow_dispatch` for manual builds
- push to `main` also builds
- verifies the exact base-image SHA-256
- downloads `magiskboot`
- unpacks the boot/recovery image
- patches `twres/portrait.xml`
- adds the read-only inspection helper
- repacks using the original boot-image headers/compression handling
- verifies the resulting image
- publishes the image as a GitHub Release asset

Magisk's official documentation states that `magiskboot unpack` extracts boot-image components and `magiskboot repack` rebuilds them using the original image's headers and compression format. citehttps://github.com/topjohnwu/Magisk/blob/master/docs/tools.md

## Safety

The current milestone contains no partitioning command. Do not add destructive SD commands until the adopted-storage implementation has been verified against the ROM's own vold behavior.
