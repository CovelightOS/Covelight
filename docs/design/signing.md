# Content Signing Design

> **Status: PLANNED — written by task T0.3** (`docs/plan/01-phase0-foundation.md`). Security review required before T1.4 implements it. Nothing may depend on signing behavior until this doc is approved.

## Will cover
- Ed25519 key hierarchy: project content key; relationship to per-parent pairing keys (Tier 2, see ARCHITECTURE §4 — referenced, not duplicated)
- PCK signature format: detached vs embedded (open question, decided here)
- Verification flow in the shell (consumed by T1.4's GDExtension)
- Project key storage & access control
- Rotation and compromise procedure
- Explicit non-goals: signing is authenticity, not encryption; no DRM claims
