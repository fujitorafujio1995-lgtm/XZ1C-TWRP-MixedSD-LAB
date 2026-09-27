# XZ1C TWRP Mixed SD v2.3 — Dynamic Capacity UI

Flow:
Advanced -> Partition the memory card -> Format SD / Load SD.

Load SD reads the real inserted card capacity and pushes it into TWRP
DataManager using the TWRP CLI `set` command. The UI then uses that
real total for its partition controls.

Internal/Adopted is the controlling value. Slider or numeric input changes
Internal; Portable is recomputed as Total - Internal. Create partitions
passes the current UI values to the backend, which re-reads the real card
capacity before writing GPT.

No hard-coded 64/55 GiB defaults.

Private adopted storage remains the Android vold responsibility.
