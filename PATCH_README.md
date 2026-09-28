# MixedSD v6

Keeps Advanced -> Partition SD card -> Select Storage -> partsdcard. Only the stock partsdcard page is replaced.

Three user regions: App/Internal F2FS, Download/Public exFAT, Swap Linux swap. No fourth user-visible region. android_meta is a hidden 16 MiB backend partition.

If selected total is below maximum, the remainder stays unallocated. Full mode activates only when all three are enabled and the sum equals maximum; then changing one value redistributes the remaining capacity across the other two. Otherwise the other regions do not move.

Configure/Format are destructive SD operations and require TWRP confirmation.
