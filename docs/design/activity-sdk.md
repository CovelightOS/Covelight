# Activity SDK Contract

> **Status: PLANNED — written by task T1.3** (`docs/plan/02-phase1-shell.md`), BEFORE any activity is built. The template activity in `/activities/_template` is the executable companion to this doc.

## Will cover
- Activity manifest: id, version, min-shell version, declared layouts
- Entry-point interface & lifecycle (start / pause / end)
- Audio helper API — all feedback and guidance is audio; no text ever reaches the child (CLAUDE.md #1)
- Input API — touch primitives with minimum target sizes for small hands
- Progress-storage API — local only, no telemetry (CLAUDE.md #5)
- Hard rules: textless; calm endings (no scores, streaks, replay-pressure — CLAUDE.md #4); responsive layout declaration mandatory (phone portrait → 4:3 tablet)
