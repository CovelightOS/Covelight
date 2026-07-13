# Phase 0 — Foundation

**Goal:** a repo a stranger can clone, understand, and contribute to; CI that enforces the rules; the cryptographic design settled before any code depends on it.
**Done when:** repo skeleton merged, CI green on a trivial change, signing design doc approved, namespaces claimed.

## Tasks

### [ ] T0.1 — Repo skeleton [CC]
Create the directory layout from CLAUDE.md (`/shell /activities /app /companion /os /syncd /devices /docs /tools`), each with a stub README stating what lives there and which tier it serves. Move the existing docs (README, ARCHITECTURE, CLAUDE, device-database, plan/) into place.
**Acceptance:**
- [ ] Layout matches CLAUDE.md exactly (or CLAUDE.md updated in same PR)
- [ ] Every directory README names its tier (shared / tier1 / tier2 / meta)
- [ ] Root README links resolve

### [ ] T0.2 — CI scaffold [CC]
GitHub Actions: markdown lint + link check on all docs; placeholder jobs (matrix-ready) for godot-export, android-build, rust-test — each currently a no-op that succeeds, so later phases fill in real steps without re-plumbing.
**Acceptance:**
- [ ] CI runs on PR, green on the skeleton
- [ ] Broken doc link fails CI (test with a deliberate break, then fix)

### [ ] T0.3 — Content-signing design doc [CC, security]
`docs/signing.md`: Ed25519 key hierarchy (project content key; per-parent pairing keys are Tier 2 §4 material, referenced not duplicated), PCK signing format (detached signature file vs embedded — decide and justify), verification flow in the shell, key storage for the project key, rotation/compromise procedure. **This blocks T1.4 and must be reviewed before it.**
**Acceptance:**
- [ ] A reader can implement signer and verifier from the doc alone
- [ ] Compromise/rotation procedure exists
- [ ] Explicitly states what is NOT protected (signing ≠ encryption; no DRM claims)

### [ ] T0.4 — Signing tool [CC, security] (depends: T0.3)
`/tools/sign`: Rust CLI — `sign <file>`, `verify <file>`, `keygen`. This is the first code in the shared `covelight-crypto` crate that the shell's GDExtension (T1.4) and later `syncd` will both consume — one implementation of Ed25519 usage across the project.
**Acceptance:**
- [ ] keygen/sign/verify round-trip test in CI
- [ ] Tampered-file test fails verification
- [ ] Crate structure allows reuse (`covelight-crypto` lib + thin CLI)

### [ ] T0.5 — Contribution docs [CC]
`CONTRIBUTING.md`: how to pick a task from `/docs/plan`, PR conventions, the `security` and `honest-labeling` labels, code of conduct, "you don't need to be a game dev" framing with the contributor lanes from the README.
**Acceptance:**
- [ ] A newcomer can go from clone to first-PR instructions without asking anything

### [ ] T0.6 — Claim namespaces [human]
`covelight.org`, `covelight.dev`, GitHub org `covelight`. Transfer repo into the org.

### [ ] T0.7 — Trademark check [human]
USPTO/EUIPO search on "Covelight" (the dormant "Covelight Systems" entity was previously flagged — resolve whether it matters). Outcome recorded in `docs/decisions/`.

### [ ] T0.8 — License decision [human, blocks first release only]
GPLv3 vs Apache-2.0, possibly per-component (copyleft OS/daemon, permissive SDK to maximize activity contributions is a defensible split). Record in `docs/decisions/`, then [CC] task to apply headers.

## Open questions
- (design, blocking T0.3) Detached vs embedded PCK signatures — decide in T0.3, not before.
- (human, non-blocking) GitHub org name fallback if `covelight` is taken.
