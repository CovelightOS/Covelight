# /tools

Project-wide tooling, not child-facing and not tier-specific: the
`covelight-crypto`-based signing CLI (`sign`/`verify`/`keygen`) shared by the
shell's GDExtension and `covelight-syncd`, plus CI helpers.

**Tier:** meta

**Status:** `covelight-crypto` + `sign` CLI implemented (T0.4), per
`docs/design/signing.md` (T0.3). CI helpers (T0.2) done. See
`docs/plan/01-phase0-foundation.md`.

- `covelight-crypto/` — Rust library: Ed25519ph signing/verification, the
  76-byte sidecar format. The only Ed25519 implementation in the project;
  T1.4 (shell GDExtension) and Phase 4 (`covelight-syncd`) consume it.
- `sign/` — thin CLI over the crate: `sign keygen`, `sign sign`,
  `sign verify`.
- `check_links.py` — internal doc-link checker (T0.2).
