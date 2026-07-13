# /devices

The device database: hand-curated + ingested data on which phones work for
Covelight, at both tiers — six-requirement scoring model (display, touch,
GPU, audio out, charging, USB gadget), tiered as verified / supported /
candidate / blocked / unviable. Design in `docs/devices/device-database.md`.

Covers Tier 1 (vendor-skin device-test matrix, `docs/devices/device-matrix.md`)
and Tier 2 (bootloader-unlock/porting data) — neither tier alone.

Empty for now: no `data/*.yml` or `tools/score.py` exist yet. They land in
Phase 6 with researched, sourced values — not placeholders.

**Tier:** cross-tier

**Status:** not started — see `docs/plan/04-phase3-to-6-skeletons.md`
(Phase 6, device ecosystem).
