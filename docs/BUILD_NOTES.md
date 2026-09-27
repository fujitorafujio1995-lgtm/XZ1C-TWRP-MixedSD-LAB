TWRP supports the command-line `set VARIABLE [VALUE]` interface.
The v2.3 Load SD helper uses it to transfer probe results into
DataManager variables, avoiding hard-coded card sizes.

The GUI uses slidervalue + compute for synchronized Internal/Portable
values and an input control for direct numeric entry.

If the base recovery does not provide the `twrp` CLI/FIFO endpoint,
the helper fails instead of guessing a capacity. A recovery-binary
rebuild would then be required.

The partition backend re-reads actual capacity and sector size immediately
before GPT writes.
