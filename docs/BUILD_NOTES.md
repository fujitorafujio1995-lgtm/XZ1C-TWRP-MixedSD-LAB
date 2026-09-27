# Build notes

The supplied image is an Android boot image with a legacy header (version 0), 4096-byte pages, a gzip-compressed ramdisk, and no DT section. The ramdisk already contains `twres/portrait.xml`, `/system/bin/sgdisk`, `/system/bin/blockdev`, and the normal TWRP command-line utilities.

The patch therefore leaves the compiled TWRP executable untouched and modifies only ramdisk resources/scripts. This is intentionally a reconstruction/patch pipeline rather than a claim of recovered TWRP source.
