# XZ1C Mixed SD layout

Advanced menu keeps the original TWRP "Partition SD Card" entry unchanged.

A separate entry is added:

Partition the memory card

The custom UI uses one three-color proportional bar:

- GREEN  = EXT / App partition
- YELLOW = Download / Public partition
- RED    = Swap partition

The three values are linked:

EXT + Download + Swap = usable SD capacity minus GPT/alignment overhead.

Changing one value recalculates the other values.

The "File System" selector belongs to the EXT/App
partition and selects EXT3 or EXT4. It is not a fourth partition.

The original TWRP partitionsd implementation must remain untouched.

The custom Mixed SD backend must re-read the physical SD
capacity and sector size before any partition operation.

The UI must never rely on a hard-coded SD capacity.
