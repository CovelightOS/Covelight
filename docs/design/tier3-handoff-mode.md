# Tier 3: Handoff Mode — Design

> Target location: `docs/design/tier3-handoff-mode.md`
> Status: Draft — pending ADR acceptance
> Related: `docs/decisions/ADR-XXX-tier3-handoff-mode.md`

## What Tier 3 is

Handoff Mode lets a parent lend their **own phone** to a child for a short, supervised session. The Covelight child experience is locked to the foreground using the platform's consumer containment feature. Exit requires the parent's own lock screen credential.

Guarantee strength across tiers (strongest first — note this is *not* tier-number order):

| Rank | Tier | Deployment | Containment mechanism | Permitted language |
|------|------|-----------|----------------------|-------------------|
| 1 | Tier 2 — Covelight OS | Dedicated device, unlocked bootloader | Structural: radios compiled out, dm-verity, read-only root | "air gap", "structural" |
| 2 | Tier 1 — Covelight App | Dedicated Android 8+ device, factory provisioned | Device Owner lock task (true kiosk) | "kiosk", "locked down" |
| 3 | Tier 3 — Handoff Mode | Parent's own phone, temporary session | Consumer screen pinning / Guided Access | "containment", "handoff", "convenience" |

## What Tier 3 is NOT

- Not a kiosk. Not locked down. Never "air gap."
- Not a substitute for Tier 1. It is a *trial and a stopgap.*
- Not childproof against a child who knows the parent's PIN.
- Not immune to interruption (incoming calls surface over a pinned app on Android).

These limits are shown to the parent **in the app, before first use** — the disclosure screen is a launch requirement, not a nice-to-have.

## Android design

### Mechanism

`Activity.startLockTask()` called from a non-Device-Owner app triggers **consumer screen pinning**: the app is fixed to the foreground; status bar, notifications, home, and recents are suppressed. No special permission is required beyond the user having screen pinning enabled in Settings.

### Entry flow ("Hand to child")

1. Parent opens the Covelight app on their phone.
2. Taps the single, prominent **Hand to child** button.
3. First run only:
   a. App detects screen pinning is disabled → shows a 2-step illustrated guide → deep-links to `Settings.ACTION_SECURITY_SETTINGS` (exact screen varies by OEM; see OEM matrix).
   b. App shows the one-time limits disclosure (interruptions, PIN caveat, "this is not the kiosk").
4. App switches to the child UI (same Godot shell, same signed PCK content) and calls `startLockTask()`.
5. Android shows its own one-time pinning confirmation dialog → parent confirms → hands the phone over.

Steady-state, this is genuinely one tap + one hand-over.

### Exit flow

- Parent holds **Back + Recents (or the gesture-nav equivalent: swipe up and hold)**.
- Android unpins and immediately demands the **device lock screen credential** (PIN / pattern / biometric) if "Ask for PIN before unpinning" is enabled — the entry flow verifies this toggle and refuses to start a session without it.
- App detects unpin (`onTaskRemoved` / lifecycle + `ActivityManager.getLockTaskModeState()`), returns to the parent UI.

No Covelight-side key management is involved: the escape hatch *is* the parent's lock screen. This keeps the "private keys never on the child device" principle trivially satisfied — the parent's phone is a parent device that temporarily renders child content.

### Content pipeline

Unchanged. The same Godot 4 shell runs the same Ed25519-signed PCK bundles. On the parent's phone the companion app and the child shell are co-resident, so "sync" is an internal handoff, but signature verification still runs — unsigned content never loads, on any tier.

### Session hygiene (attention-engineering review required)

- Optional parent-set session length with a **calm wind-down cue** (e.g., ambient dimming + a gentle audio motif), never a countdown, never an alarm, never a reward for continuing.
- No session stats, no "come back tomorrow", no streaks. Session end returns to a neutral parent screen.

### OEM test matrix (initial)

| OEM / skin | Pinning settings path | Known quirks |
|---|---|---|
| Pixel / AOSP | Security → More → App pinning | Baseline behavior |
| Samsung One UI | Security & privacy → Other → Pin app | "Ask for PIN" toggle naming differs |
| Xiaomi HyperOS | Verify | Historically aggressive task killers; verify pin survives |
| Others | Populate as reports arrive → `docs/devices/` | — |

## iOS design (conditional — pending separate ADR)

### Mechanism

**Guided Access** (Settings → Accessibility → Guided Access). Parent opens the Covelight app, **triple-clicks the side button**, session starts. Exit: triple-click again + Guided Access passcode or Face ID/Touch ID.

### Hard limitations

- **No one-tap entry.** `UIAccessibilityRequestGuidedAccessSession(enabled:)` succeeds only on MDM-supervised devices. On consumer iPhones the app cannot start Guided Access itself. The app can only:
  - detect the state via `UIAccessibility.isGuidedAccessEnabled` and post a "handoff active" child UI;
  - show a one-time illustrated setup guide for enabling Guided Access and the triple-click.
- **No USB-C sync.** Apple's serial API restrictions stand. Content would ship **inside the app bundle**, updated via App Store releases.

### The constitutional question (must be answered in its own ADR before any iOS code)

App Store updates are over-the-air delivery of child-facing content. Covelight's inviolable constraint says *No OTA content to the child app.* Two readings:

1. **Strict:** any OTA delivery violates the constraint → iOS Tier 3 is impossible; drop it.
2. **Parent-mediated:** the parent's Apple ID controls updates (and can disable auto-update), so an App Store release is a parent-gated channel closer in spirit to USB sync than to silent OTA.

Whichever reading is adopted, PCK signature verification still runs inside the bundle at load time, and the decision is recorded as an ADR — not decided by implementation drift.

## Marketing copy rules (binding)

- Name: **Handoff Mode**. Tagline register: *"Lend your phone safely for twenty minutes."*
- Forbidden for Tier 3: "kiosk", "locked down", "air gap", "secure device", "childproof".
- Every Tier 3 mention in public copy links or points to the tier comparison, ordered by guarantee strength.
- Funnel framing is encouraged: Handoff Mode → "that old phone in your drawer" → Tier 1 → Tier 2.

## Open questions

- Wind-down cue design — needs review against the attention-engineering ban before implementation.
- Should Handoff Mode refuse to start if the phone has no lock screen credential set? (Proposed: yes — without a credential, unpinning is unguarded and the limits disclosure becomes misleading.)
- Minimum Android version: pinning exists since 5.0, but aligning with the existing Android 8+ floor keeps the story simple. (Proposed: Android 8+.)
