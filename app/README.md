# /app

Tier 1: the Android kiosk wrapper. Kotlin host app embedding the Godot
Android export; Device Owner provisioning, lock-task kiosk mode, radios
disabled by policy, launcher replacement. No Google Play Services
dependency (CLAUDE.md #9).

Protection here is **policy-based**, not structural — never describe it with
"air gap" or "cannot network" (CLAUDE.md #7; ARCHITECTURE.md §3.3).

**Tier:** tier1

**Status:** not started — see `docs/plan/03-phase2-kiosk.md` (Phase 2, first
family-usable release).
