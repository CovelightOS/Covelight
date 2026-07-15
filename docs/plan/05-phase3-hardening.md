# Phase 3 — Tier 1 Hardening

**Goal:** make the Tier 1 kiosk claim hold outside the reference test device — across real vendor skins, on F-Droid, and with a way for families to update the app that never opens the child device to networking.

**Done when:** the device-test matrix has live reporting infra and a first-pass entry for every priority vendor (even if the entry is honestly "untested"); the vendor-quirk workflow has been exercised at least once on a real reported quirk; F-Droid submission is filed; the update channel ships in a Companion release.

**Dependencies (blocking):**
- **Phase 2 (`docs/plan/03-phase2-kiosk.md`, T2.1–T2.8) must ship first.** The device-test matrix tests a real APK on real vendor hardware — as of this writing `/app` is a stub ("not started") and the only kiosk work that exists is `spike/kiosk-device-owner`, a pre-Phase-2 spike that produced a *reusable findings template*, not results from real hardware. Do not start T3.1 data collection before a T2.8 release exists.
- **T0.8 (license decision)** must land before T3.3 (F-Droid). F-Droid requires a FOSS license; `docs/decisions/0003-license-choice.md` is still 🔓.

## Design constraints in force (CLAUDE.md)

- **#5 no telemetry** — the device-test matrix is community-submitted (PR/issue), never auto-collected from devices in the field.
- **#7 honest tier labeling** — matrix entries, F-Droid listing copy, and update-channel copy all keep the policy-not-structure distinction (ARCHITECTURE §3.3). Never let a "passed the matrix" result read as "cannot be escaped."
- **#8 the kiosk never weakens itself** — the update channel is not a re-enable path. No "check for updates" code ships in child-reachable `/app` code; the trigger is always Companion-initiated over USB.
- **#9 no Play Services deps** — carried into the F-Droid dependency audit.
- **#10 no OTA to the child app** — the update channel reuses T2.6's USB-session model; it does not add a new content/code delivery path.

ARCHITECTURE §3.3 ("Honest limitations") is the spec for what this phase is allowed to claim.

## Tasks

### [ ] T3.1 — Device-test matrix: checklist, reporting template, results home [CC]
Promote the spike's `spike/kiosk/FINDINGS.md` template (per-policy checklist, logged-vs-independently-verified columns, radio-verification-via-second-device method, escape-attempt protocol) into the live `docs/devices/device-matrix.md`, replacing its current "PLANNED" stub. Define where filled-in results actually live — one file per tested device, not a single mutable scratch file (the spike template already says this; make it real): e.g. `docs/devices/results/<vendor>-<codename>.md`. Priority vendors per the committed skeleton: Samsung, Xiaomi (MIUI/HyperOS), Oppo family, Lenovo/Moto tablets. Amazon Fire OS gets a row in the matrix but **no support claim** until it's actually been tested (Fire OS's Device Owner story is unverified — flag this, don't assume it works the same as stock AOSP).
**Acceptance:**
- [ ] `docs/devices/device-matrix.md` contains the full checklist + reporting template (not a stub)
- [ ] Results directory exists with a README explaining the one-file-per-device convention
- [ ] Template keeps the logged-result vs. independently-verified distinction from the spike (a passing log line is not a verified claim)
- [ ] Priority vendor list matches the skeleton; Fire OS row explicitly marked "unverified, no claim"
- [ ] Linked from `CONTRIBUTING.md` so community testers can find it without reading the plan doc

### [ ] T3.2 — Vendor-quirk triage workflow [CC]
No vendor quirk is confirmed yet — MIUI's aggressive background-kill is an *anticipated* risk (ARCHITECTURE §3.3, CLAUDE.md conventions), not a tested finding. Build the repeatable process, not a fix list: a quirk-report template (what device, what was tried, log output) → reproduction requirement on real hardware (same rigor as T2.2's abuse test — no fix ships against an unreproduced report) → classification (policy-level fix in `/app` vs. documented limitation vs. escalation that affects the ARCHITECTURE §3.3 claim) → the fix lands with a named device entry in the matrix. CLAUDE.md's Android convention already requires vendor workarounds to be "documented per-device, never silently hacked in" — this task is that rule turned into an actual workflow.
**Acceptance:**
- [ ] Quirk-report template exists (GitHub issue template or a workflow doc under `docs/`)
- [ ] Triage flow documented end to end: reproduce → classify → fix-or-document → update the matrix entry
- [ ] One dry run completed against a mock report, producing a correctly-labeled artifact
- [ ] Explicit written rule: no silent workarounds; every quirk fix traces to a named device+entry

### [ ] T3.3 — F-Droid submission [CC+human] (depends: T0.8 license, Phase 2 shipped)
Verify F-Droid's *current* inclusion criteria at task start, not from this plan doc — reproducible-build requirements, anti-features policy, and non-free-dependency rules evolve and this file will be stale by execution time. Fix whatever fails (most likely: reproducible build wiring in CI). Submit via an `fdroiddata` merge request.
**Acceptance:**
- [ ] Current F-Droid inclusion criteria reviewed and the review dated in the PR description
- [ ] CI produces a reproducible build, or the gap is documented honestly if not yet achievable
- [ ] Dependency audit confirms no non-free dependencies (extends T2.1's Play-Services audit)
- [ ] Metadata submitted via an `fdroiddata` merge request (human: F-Droid's review/signing process is external)
- [ ] Submission is filed and tracked (merged inclusion is not required for this task to be done — F-Droid's review queue is outside our control)

### [ ] T3.4 — Update channel [CC+human]
Companion-mediated app update: a human opens the Companion, it checks for a new Covelight release, downloads the signed APK, and pushes it to a provisioned device over the same USB session T2.6 uses for PCK import. No background/automatic check ships in `/app` — the trigger is always a parent action in the Companion, never code running on the child device (constraint #10, #8).
**Acceptance:**
- [ ] Companion detects a new release and pushes an updated signed APK to a provisioned device over USB
- [ ] Update succeeds without re-running Device-Owner provisioning, or the re-provision requirement is documented honestly if unavoidable
- [ ] Dependency/code audit confirms zero network-facing update-check path in `/app` (same audit style as T2.1)
- [ ] Update flow tested on a device with radios policy-disabled, proving USB alone is sufficient

### [ ] T3.5 — Phase 3 close-out / release [human] (depends: all above)
Tag once the matrix has first-pass entries for every priority vendor, the F-Droid submission is filed, and the update channel has shipped in a Companion release.

## Parking lot (carried from the skeleton, still out of scope)
- Accessibility features (motor-impairment input options)
- Multi-child profiles

## Open questions
- (blocking, sequencing) Confirmed above: Phase 3 cannot meaningfully start — no APK to test — until Phase 2 ships. Do not open T3.1 data-collection work early even though the workflow/template pieces (T3.1, T3.2 scaffolding) can be written now.
- (blocking T3.3) License decision (T0.8) — F-Droid requires a FOSS license; `docs/decisions/0003-license-choice.md` is still open.
- (non-blocking, engineering) Does Amazon Fire OS support standard Device Owner provisioning at all, or does its GMS-free fork diverge enough that the whole T2.2 policy set needs re-verification there? Answer before adding anything beyond an "unverified" row.
- (non-blocking, engineering) Does a Companion-pushed app update ever require re-running Device-Owner provisioning (e.g. a signing-key rotation or a major manifest change)? Verify on real hardware in T3.4 rather than assuming ADB-level app updates are always transparent to Device Owner state.
- (non-blocking, honest-labeling) Is F-Droid positioned to parents as an install/discovery channel only, with the Companion always doing the actual push (since a provisioned device's radios are policy-disabled and can't reach F-Droid's own client anyway), or does the setup guide need updating to make this explicit? Resolve before T2.7/T3.4 documentation is finalized.
