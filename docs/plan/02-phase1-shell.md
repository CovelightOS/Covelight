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

### [x] T1.3 — Activity SDK contract [CC] (write BEFORE T1.5–T1.7)
`docs/design/activity-sdk.md` + `/shell/sdk/`: activity manifest (id, version, min-shell, declared layouts), entry-point interface, audio helper API (all speech/feedback via audio cues), input API (touch primitives sized for small hands), progress-storage API (local only, per constraint #5), lifecycle (start/pause/end). **Hard SDK rules:** textless; calm endings (no score screens, streaks, or "play again?" pressure loops); responsive layout declaration mandatory. Orientation decided: portrait-only, always (`display/window/handheld/orientation` locked in both `shell/project.godot` and every activity project) — a deliberate scope-narrowing tradeoff, see the doc's §9.
**Acceptance:**
- [x] A template activity (`/activities/_template`) builds and runs in the shell — own GUT suite proves the full contract (manifest validity, lifecycle, no failure states, textlessness, touch-target/safe-margin sizing) against a real instantiated scene, run locally against Godot 4.7.stable (7/7 passing) and wired into CI (`godot-activity-template`); real signed-PCK loading through `Shell.start_activity()` is T1.4's job, not yet built, and this doesn't claim to exercise that path — see the doc's §10
- [x] SDK doc sufficient for an outsider to build an activity without reading shell source — `docs/design/activity-sdk.md`
- [x] Review checklist (`docs/guides/activity-review.md`) encodes constraints #1 and #4 as concrete checks, backed by `tools/lint_activity.sh` (static) and `shell/sdk/text_audit.gd` (runtime), both verified against real hits and real clean output

### [x] T1.4 — PCK loading + signature verification [CC, security] (depends: T0.3, T0.4)
GDExtension in Rust wrapping `covelight-crypto`: verify Ed25519 signature per `docs/design/signing.md` **before** `load_resource_pack`. Unsigned/tampered PCKs are rejected silently from the child's perspective (logged for parents). Research gate (`docs/research/godot-pck-gdextension.md`) confirmed Godot's `load_resource_pack()` is path-only with no pre-mount hook — verify-then-load from outside the engine, exactly as designed, is the only shape the engine supports; no contradiction found. One residual, honestly documented finding not previously known: a TOCTOU window between verify and load (Godot opens its own file handle; locks are advisory on Linux/Android) — doesn't expand `docs/design/signing.md`'s threat model (still requires write access to an already-protected path) but is now named in that doc's "Non-goals" section rather than left implicit.
**Acceptance:**
- [x] Signed PCK loads; unsigned and tampered PCKs do not (automated tests, all three cases) — `shell/tests/test_pck_loader.gd`, real Ed25519 signing via a `tools/sign` subprocess (not a hand-built fixture), run locally against Godot 4.7.stable (8/8 passing alongside T1.2's suite) and wired into CI (`godot-test`, `needs: build-gdextension`)
- [x] No debug bypass flag exists in any build configuration (constraint #3) — verified by design: `covelight_crypto::TRUSTED_KEY_BYTES` ships empty (no real project key exists yet — a governance decision, not this task's), so `PckVerifier::verify_pck` (the only method `PckLoader`/`shell.gd` ever calls in production) currently rejects everything, correctly fail-closed; the test-only `verify_pck_with_key` sibling method is never reachable from production code and performs the same real Ed25519 check against an explicit key rather than a weaker one — documented in the crate's own doc comments
- [x] Same crate consumed here and by `/tools/sign` — no second Ed25519 implementation — `shell/rust/pck_verify` depends on `covelight-crypto` by relative path; also added `sig_path_for()` and `trusted_keys()` to `covelight-crypto` itself and deduplicated `/tools/sign`'s own copy of the sidecar-path convention into it

### [ ] T1.5 — Home screen [CC+human] — CC portion done, awaiting human verification
Textless activity chooser: large icon tiles, audio preview on tap-hold, launch on tap. Lighthouse/harbor visual identity. Human check: hand it to an actual small child if possible; watch where they get stuck. **Not checked off — the human half of [CC+human] hasn't happened yet; this box is CC's own honesty marker, not a claim of full completion.**
**Acceptance:**
- [x] Zero rendered text — `shell/tests/test_home.gd`'s `test_no_text_capable_nodes`, `TextAudit.find_text_nodes()` against the real instantiated scene
- [x] Usable at all three T1.1 test ratios — real (non-headless) window screenshots taken at all three resolutions during this task's own verification; layout numerically confirmed resolution-independent (`SafeArea` offsets, tile `custom_minimum_size`, both project-unit values under `canvas_items`/`expand`), not just eyeballed
- [x] Every interactive element ≥ the SDK's minimum touch-target size — tiles are 320×320 project units (double `LayoutConstants.MIN_TOUCH_TARGET_SIZE`, "large icon tiles" per this task's own wording), asserted directly in `test_home.gd`
- [ ] **Human: hand to an actual small child, watch where they get stuck.** This is the acceptance criterion CC cannot verify — everything else on this list is real and automated, but usability for the actual user isn't establishable from a desk.

### [ ] T1.6 — First three activities [CC+human] (depends: T1.3) — CC portion done, awaiting human verification
Built against the SDK, each exercising a different SDK surface: (1) animal sounds — tap/audio; (2) shape sorter — drag/drop; (3) color mixing — multi-touch/feedback. Each passes the T1.3 review checklist. These are the reference examples contributors copy, so code clarity outranks cleverness. **Not checked off — the human half of [CC+human] (a real child, watch, don't guide) hasn't happened; this box is CC's honesty marker.**

Established the project content-signing key here (the governance decision T1.4 deferred): keypair generated, public key embedded in `covelight_crypto::TRUSTED_KEY_BYTES`, private key custodied offline by the maintainer (gitignored `.keys/`, never committed). This is what makes the signed-PCK pipeline actually verify.

One SDK gap found and reported, not worked around (`docs/design/activity-sdk.md` §12): the SDK is duplicated into every exported PCK (activity's `res://addons/covelight_sdk/` copy vs the shell's `res://sdk/`), so PCK-loaded activity nodes are a distinct class-identity from the shell's SDK classes. Functionally harmless (activities run; the shell drives them by signal name, verified end-to-end); the clean path-alignment fix is deliberately deferred. Also fixed a real template bug found here: `manifest.cfg` wasn't in the PCK (missing from `include_filter`) — fixed in the template and all three activities.
**Acceptance:**
- [x] Each ships as a signed PCK loaded by the shell (full pipeline exercised end-to-end) — signed `.pck`+`.sig` under `shell/content/`, verified against the real project key and loaded live: `shell/tests/test_shell_state_machine.gd`'s `test_real_click_on_home_tile_launches_activity` drives a real tap → verify → load → run, and it was confirmed visually in a real window (screenshot of animal_sounds loaded via a real home-tile click)
- [x] Each passes `docs/guides/activity-review.md` — `tools/lint_activity.sh` clean on all three, each activity's own GUT suite (8–9 tests) asserts textlessness (`TextAudit`), audio-first, no failure states, calm endings, min touch-target size, and safe margins; all three green locally against Godot 4.7.stable and wired into CI (`godot-activity` matrix)
- [x] No failure states: wrong answers get gentle redirection, never negative feedback — every activity: a wrong drop drifts home / a wrong tap is impossible / any color is valid, each with a soft neutral sound, asserted in tests (`test_wrong_drop_drifts_back_with_no_penalty`, `test_no_wrong_answer_no_early_finish`, etc.)
- [ ] **Human: a real child, watch, don't guide.** The one acceptance CC cannot do from a desk.

### [x] T1.7 — Audio system [CC]
Central audio bus: cue library, per-activity audio helper backing, ducking rules, master-volume persistence. Every shell interaction has an audio response (sound-driven UI is a core requirement, not polish).

Built as an `AudioBus` autoload (`shell/audio/audio_bus.gd`) that creates two runtime buses at boot — `Chrome` (shell-level transition/UI cues) and `Content` (activity + home-tile audio, both routed to `Master`) — plus a `CueLibrary` (`shell/audio/cue_library.gd`) that looks cues up by name, real asset first, procedural placeholder tone as fallback. `ActivityAudio` (`shell/sdk/audio_cue.gd`) now routes to `Content` by changing one constant, exactly as `docs/design/activity-sdk.md` §5 said T1.7 would; `TransitionOverlay` plays distinct `transition_leave`/`transition_arrive` cues (was silent on `reveal()` before this task) and ducks `Content` around them; `HomeTile` gained an immediate `ui_tap` cue independent of what the tap goes on to trigger. That last one is a real bug found and fixed here: a tap on a tile whose PCK fails signature verification returned silently before this task (constraint #1's "no error shown" had the side effect of "no sound either") — the tap cue now fires regardless of the outcome. `docs/research/godot-audio.md` records the NotebookLM-queried AudioServer bus API this was built against, including why ducking is a deterministic bus-volume tween here rather than `AudioEffectCompressor` sidechaining.
**Acceptance:**
- [x] All shell interactions produce audio feedback — `shell/tests/test_audio.gd`, real autoloaded `AudioBus`/`CueLibrary`, no mocks; covers bus creation/routing, ducking, volume persistence-to-disk, and the two shell-level surfaces that aren't an activity's own responsibility (`HomeTile` tap, `TransitionOverlay` cover/reveal); existing `test_home.gd`/`test_shell_state_machine.gd` still green (23/23 total), and all three T1.6 activities' own standalone GUT suites re-verified unaffected (e.g. `animal_sounds` 8/8)
- [x] Placeholder cue set documented as replaceable assets (real sound design is a contributor lane) — `shell/audio/cues/README.md`: swap path is "drop a same-named `.ogg`/`.wav` in this directory," no code change; cue-name-to-trigger table kept in sync with `CueLibrary._PLACEHOLDER_TONES`

Master-volume persistence (`AudioBus.set_master_volume()`/`get_master_volume()`, `user://settings/audio.cfg`) is the API surface only — no volume control exists anywhere in `/shell`'s child-reachable scenes; it's built for T2.3's parent menu to call, per this task's design notes.

### [x] T1.8 — Desktop test harness [CC]
`just run` / `just test` developer loop: launch shell with local activities, simulate the three form factors, run all tests. This is the contributor on-ramp — friction here is friction on requirement 3.

Built as a repo-root `justfile`: `just run [form]` (builds the T1.4 GDExtension if needed, runs Godot's one-time `--import` class-registration pass, launches a real window — `form` is `phone-portrait` default, `phone-landscape`, or `tablet`, the same three ratios `shell/README.md`'s "Stretch strategy" section documents), `just test-shell` (shell's own GUT suite), `just test-activity <name>` (one activity's own suite), and `just test` (everything — shell plus every first-party activity, mirroring `.github/workflows/build.yml`'s `godot-test` + `godot-activity` matrix so "green locally" and "green in CI" mean the same thing). `docs/guides/building-activities.md` (replacing its stub) is the full contributor walkthrough this harness is the on-ramp for.
**Acceptance:**
- [x] Clone → running shell in ≤ 3 commands on a clean machine (document them in /shell/README) — `git clone && cd covelight && just run` is two commands; `shell/README.md`'s "Running it locally" documents this plus the manual command equivalents. Verified for real, repeatedly, on this dev machine (all three `run` form factors real-windowed, `test-shell`/`test-activity`/`test` all green); the ≤3-command *sequence* was additionally confirmed against a genuinely clean tree (`git archive` export — no `.godot/` cache, no `target/`, no compiled GDExtension binary) via dry-run and a real run that correctly invoked the GDExtension build before failing on unrelated host disk exhaustion partway through the from-scratch `cargo build` — a pre-existing condition on this development machine, left alone rather than remediated by this task, and honestly noted in `shell/README.md` rather than hidden. A from-scratch container run (the more rigorous version of this check) is worth re-doing once there's disk headroom; not blocking.

## Open questions
- (design, non-blocking) Progress data model: per-activity opaque blobs vs shared schema — start opaque, revisit at Phase 4 (syncd may want to surface progress to parents).
- (human, non-blocking) Voice/sound identity: record original cues vs licensed library — affects T1.7 asset replacement only.
