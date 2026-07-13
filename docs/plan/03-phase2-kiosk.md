# Phase 2 — Tier 1: Android Kiosk + Companion Setup

**Goal:** the first family-usable release — a phone or tablet that does only Covelight, set up by a non-technical parent.
**Done when:** a parent with a factory-reset device and our desktop helper reaches a locked-down, child-ready device in under 15 minutes without seeing a terminal; and can undo it just as cleanly.

## Design constraints in force (CLAUDE.md)
#7 honest labeling · #8 kiosk never weakens itself · #9 no Play Services deps · #10 no OTA content to the child app. ARCHITECTURE §3 is the spec.

## Tasks

### [ ] T2.1 — Android wrapper for the shell [CC]
Godot Android export embedded in a Kotlin host app (`/app`). Fullscreen immersive, screen-on policy during activities, hardware back consumed.
**Acceptance:**
- [ ] Shell + T1.6 activities run on a physical Android 8+ device (human verify)
- [ ] CI builds the APK (fills the android-build placeholder)
- [ ] Zero Google library dependencies (verified by dependency audit in CI)

### [ ] T2.2 — Device Owner + lock-task kiosk [CC+human, security]
`DeviceAdminReceiver`, Device Owner policies per ARCHITECTURE §3.1: persistent launcher + lock-task; Wi-Fi/BT/mobile-data disabled; status bar suppressed; installs, safe-mode, and settings-reset blocked; keyguard disabled; boot-persistent.
**Acceptance:**
- [ ] Home/back/recents all remain inside Covelight; reboot returns to Covelight
- [ ] Notification shade cannot be pulled; no system UI reachable
- [ ] Radios verifiably off (human check with a scanner/second device)
- [ ] "Small child abuse test" on real hardware: random mashing, swiping, button-holding for 10 minutes — no escape (human)

### [ ] T2.3 — Parent exit path [CC+human, security]
Hidden deliberate gesture (e.g., 5-second corner hold) → parent PIN screen (text allowed: parent-facing) → parent menu: volume, content list, exit-kiosk (PIN + confirmation). Rate-limited PIN attempts.
**Acceptance:**
- [ ] Gesture undiscoverable by the T2.2 abuse test
- [ ] PIN rate-limiting works; no PIN recovery backdoor in child-reachable code (recovery runs through the Companion over USB)

### [ ] T2.4 — Companion: provisioning wizard [CC+human]
Tauri desktop app (`/companion`), bundling ADB. Guided flow: prerequisites (factory reset, **remove SIM**, enable developer mode + USB debugging with per-step screenshots) → cable detect → `dpm set-device-owner` → policy verification → done screen. Every failure state gets a plain-language recovery path. **This is the most important UX surface in the project.**
**Acceptance:**
- [ ] Fresh factory-reset device → child-ready in ≤ 15 min by a non-technical tester (human, someone who is not you)
- [ ] All error states tested: wrong cable, debugging off, accounts still present, unsupported device
- [ ] Never shows a terminal or asks the parent to type a command

### [ ] T2.5 — Unprovision flow [CC+human]
Companion-driven clean removal: exit kiosk, remove Device Owner, restore defaults, optional factory reset. Parents must trust the door out as much as the lock.
**Acceptance:**
- [ ] Device returns to normal Android with no residue (human verify)
- [ ] Flow works even if the app is crashed/wedged (ADB-level fallback)

### [ ] T2.6 — Signed PCK import [CC, security] (depends: T1.4)
Content addition without OTA (constraint #10): Companion pushes signed PCKs over the USB session; app verifies (T1.4 path) before making them loadable. Removal likewise.
**Acceptance:**
- [ ] Unsigned/tampered PCK rejected end-to-end
- [ ] Import/removal round-trip test

### [ ] T2.7 — Setup & safety guide [CC, honest-labeling]
`docs/tier1-setup.md` + Companion copy: what protection Tier 1 provides (policy) and does not (structural) in plain language; SIM removal; the "don't install pending vendor updates on drawer phones" warning; factory-reset disclosure upfront.
**Acceptance:**
- [ ] Every safety claim passes the honest-labeling review against ARCHITECTURE §3.3
- [ ] Reading level suitable for non-technical parents

### [ ] T2.8 — Release v0.1 [human] (depends: all above + T0.8 license)
Tag, signed APK + Companion builds, release notes, LinkedIn launch coordination.

## Open questions
- (engineering, blocking T2.4) Minimum Android version — proposal: 8.0. Confirm by testing Device Owner + lock-task behavior on the oldest real device available.
- (engineering, non-blocking) Tablet-specific provisioning quirks (no telephony stack) — expect fewer problems, verify on one real tablet.
- (design, non-blocking) Multiple children per device: out of scope v0.1 (parking lot).
