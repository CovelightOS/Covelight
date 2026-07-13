# Research Notes

External research findings — distilled, committed, versioned. This is how NotebookLM (or any research pass) reaches Claude Code: **the repo is the bridge**, not a live connection.

## Why notes live here
Claude Code sessions read files on demand. A 2 KB distilled note costs almost nothing and is always current with the branch. A live query to an external service costs more, can go stale against the repo, and creates a second source of truth. Same rule as the rest of `docs/`: **link, don't duplicate; the repo is authoritative.**

## Format
Every note carries a header:

```text
# <Topic>
**Researched:** YYYY-MM-DD · **Sources:** <what was actually consulted>
**Confidence:** high / medium / low — and what would raise it
**Affects:** <task IDs from docs/plan/>
```

Then: findings as bullets, **contradictions with our plan called out explicitly**, and unknowns listed as open questions (which become verification tasks — not assumptions).

## Rules
1. A finding that contradicts a plan task does not silently update it. Open a PR against the plan doc citing the note.
2. Unknowns stay unknown. "The docs don't say" is a valid, valuable finding — it becomes a `[human]` verification task on real hardware.
3. Date everything. Android policy, F-Droid criteria, and vendor bootloader rules all move; a note without a date is a trap.

## Expected notes (Phase 0–2)
- `device-owner.md` — DevicePolicyManager: which kiosk policies are documented, min API levels, documented limitations (blocks T2.2)
- `godot-pck-gdextension.md` — runtime PCK loading, GDExtension on Android, GL Compatibility limits (blocks T1.4)
- `fdroid-criteria.md` — current inclusion requirements (affects Phase 3)
