# Phase 1 — Shared Platform (Godot shell, SDK, first activities)

**Goal:** the thing children actually use — runnable on a desktop, testable by anyone, identical across both future tiers.
**Done when:** the shell boots to a textless home screen, loads three signature-verified activities, runs on phone and tablet aspect ratios, and a stranger can build a new activity from the SDK docs in a weekend.
**This is the critical path.** Nothing in Phases 2+ matters until this exists.

## Design constraints in force (CLAUDE.md)
#1 textless kid UI · #2 Godot-only content · #3 unsigned content never loads · #4 no attention engineering · #5 no telemetry.

## Tasks

### [x] T1.1 — Godot project bootstrap [CC]
Godot 4.x project in `/shell`. **GL Compatibility renderer** (weak tablet GPUs are in scope — ARCHITECTURE §3/§4). Responsive viewport scaffolding covering ~16:9 phone portrait → 4:3 tablet landscape. CI: headless export check replaces the placeholder job.
**Acceptance:**
- [x] Runs on desktop at three test resolutions/ratios (phone-portrait, phone-landscape, 4:3 tablet) — verified by rendering `scenes/main.tscn` at all three and confirming pixel colors at all 5 shape positions; see PR for the finding that headless mode can't be used for this check (no real window) and how it was actually verified
- [x] CI exports a Linux headless build successfully — `godot-export` in `.github/workflows/build.yml`; `export_presets.cfg`'s "Linux" preset confirmed valid against the real installed engine locally (correctly progressed to a template-missing error, not a config error)
- [x] Renderer setting documented with rationale — `shell/README.md`

### [x] T1.2 — Shell state machine [CC]
Boot → home → activity-running → return-to-home. Crash containment: an activity that errors returns to home calmly (no error text — constraint #1; a gentle animation + sound). No quit path in child-reachable UI.
**Acceptance:**
- [x] State transitions covered by GUT (or equivalent) tests — real GUT 9.7.1 (built specifically for Godot 4.7.x), vendored in `shell/addons/gut/`; 4 tests, `shell/tests/test_shell_state_machine.gd`, all passing in CI (`godot-test`)
- [x] Deliberately-crashing test activity → shell survives, returns home, no text shown — `scenes/activities/crashing_activity.tscn`; the test asserts the state sequence AND recursively walks the live tree for any text-capable node type

### [ ] T1.3 — Activity SDK contract [CC] (write BEFORE T1.5–T1.7)
`docs/activity-sdk.md` + `/shell/sdk/`: activity manifest (id, version, min-shell, declared layouts), entry-point interface, audio helper API (all speech/feedback via audio cues), input API (touch primitives sized for small hands), progress-storage API (local only, per constraint #5), lifecycle (start/pause/end). **Hard SDK rules:** textless; calm endings (no score screens, streaks, or "play again?" pressure loops); responsive layout declaration mandatory.
**Acceptance:**
- [ ] A template activity (`/activities/_template`) builds and runs in the shell
- [ ] SDK doc sufficient for an outsider to build an activity without reading shell source
- [ ] Review checklist (`docs/activity-review.md`) encodes constraints #1 and #4 as concrete checks

### [ ] T1.4 — PCK loading + signature verification [CC, security] (depends: T0.3, T0.4)
GDExtension in Rust wrapping `covelight-crypto`: verify Ed25519 signature per `docs/signing.md` **before** `load_resource_pack`. Unsigned/tampered PCKs are rejected silently from the child's perspective (logged for parents).
**Acceptance:**
- [ ] Signed PCK loads; unsigned and tampered PCKs do not (automated tests, all three cases)
- [ ] No debug bypass flag exists in any build configuration (constraint #3)
- [ ] Same crate consumed here and by `/tools/sign` — no second Ed25519 implementation

### [ ] T1.5 — Home screen [CC+human]
Textless activity chooser: large icon tiles, audio preview on tap-hold, launch on tap. Lighthouse/harbor visual identity. Human check: hand it to an actual small child if possible; watch where they get stuck.
**Acceptance:**
- [ ] Zero rendered text
- [ ] Usable at all three T1.1 test ratios
- [ ] Every interactive element ≥ the SDK's minimum touch-target size

### [ ] T1.6 — First three activities [CC+human] (depends: T1.3)
Built against the SDK, each exercising a different SDK surface: (1) animal sounds — tap/audio; (2) shape sorter — drag/drop; (3) color mixing — multi-touch/feedback. Each passes the T1.3 review checklist. These are the reference examples contributors copy, so code clarity outranks cleverness.
**Acceptance:**
- [ ] Each ships as a signed PCK loaded by the shell (full pipeline exercised end-to-end)
- [ ] Each passes `docs/activity-review.md`
- [ ] No failure states: wrong answers get gentle redirection, never negative feedback

### [ ] T1.7 — Audio system [CC]
Central audio bus: cue library, per-activity audio helper backing, ducking rules, master-volume persistence. Every shell interaction has an audio response (sound-driven UI is a core requirement, not polish).
**Acceptance:**
- [ ] All shell interactions produce audio feedback
- [ ] Placeholder cue set documented as replaceable assets (real sound design is a contributor lane)

### [ ] T1.8 — Desktop test harness [CC]
`just run` / `just test` developer loop: launch shell with local activities, simulate the three form factors, run all tests. This is the contributor on-ramp — friction here is friction on requirement 3.
**Acceptance:**
- [ ] Clone → running shell in ≤ 3 commands on a clean machine (document them in /shell/README)

## Open questions
- (design, non-blocking) Progress data model: per-activity opaque blobs vs shared schema — start opaque, revisit at Phase 4 (syncd may want to surface progress to parents).
- (human, non-blocking) Voice/sound identity: record original cues vs licensed library — affects T1.7 asset replacement only.
