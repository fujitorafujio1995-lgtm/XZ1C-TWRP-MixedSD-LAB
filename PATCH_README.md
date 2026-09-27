# XZ1C Mixed SD v4 — checkbox UI patch

Baseline: 1d17c8c65933b812fcbdbe7335c889d1b5094d59
Workflow: .github/workflows/build.yml
Golden base:
260e8a41cd1e58d19b199bb0bf04aeef6ad63739dc31c8170f5bd474c0191a1a

UI:
- Stock Partition SD Card and Reload Theme remain untouched.
- New Partition the memory card entry.
- Load SD / Configure Mixed SD / Format SD / Back.
- Three regions, each with [✓]/[ ]:
  GREEN App/Internal — F2FS
  YELLOW Download/Public — exFAT
  RED Swap — Linux swap
- File-system selector is not exposed as a fourth user option.
- Total of enabled regions equals the usable allocation reported by Load SD.
- Disabled region is 0 GiB.
- Editing a region redistributes the remaining amount across the other enabled regions.
- If only one region is enabled it receives 100%.
- If no region is enabled, configuration is rejected.
- Final destructive operation uses TWRP confirmation.

NOTE:
The XML is deliberately generated using conservative TWRP controls. The exact checkbox/slider semantics are validated structurally here; the first GitHub build is the runtime compatibility test.
