# ADR-XXX: Tier 3 — Handoff Mode (Kiosk on the Parent's Own Phone)

> Renumber to the next free ADR number in `docs/decisions/` before committing.

**Status:** Proposed
**Date:** 2026-07-16
**Deciders:** Yusuf

## Context

Covelight currently defines two tiers:

- **Tier 1 (Covelight App):** Android Device Owner kiosk on a dedicated, freshly provisioned device.
- **Tier 2 (Covelight OS):** postmarketOS-based Linux OS on devices with unlockable bootloaders. The only tier where "air gap" language is permitted.

A very common real-world scenario is not covered: a parent hands their **own daily-driver phone** to a child for a short period (a car ride, a waiting room, twenty minutes of quiet). Device Owner cannot be set on an already-provisioned personal phone without a factory reset, so Tier 1 mechanics do not apply. Today Covelight has no answer for this scenario, even though it is likely the *first* contact most families would have with the project.

Forces at play:

- **Adoption funnel:** a zero-commitment "try it on your phone tonight" mode dramatically lowers the barrier to entry and feeds Tier 1/2 adoption.
- **Honest tier labeling (inviolable):** any mode on a parent's personal phone offers strictly weaker guarantees than Tier 1 and must never borrow Tier 1/2 language ("kiosk-grade", "locked down", "air gap").
- **Platform reality:** Android offers consumer screen pinning (`startLockTask()` in non-Device-Owner mode); iOS offers Guided Access. Both are OS-level, parent-credential-gated containment features — software conveniences, not structural guarantees.
- **iOS is otherwise excluded** from Covelight due to USB serial API restrictions. Handoff Mode is the one scenario where an iOS presence becomes technically plausible, because content could ship inside the app bundle rather than over USB-C.

### A note on numbering

Tier numbers in Covelight reflect **deployment model**, not a monotonic security ranking. Guarantee strength is: **Tier 2 > Tier 1 > Tier 3.** Tier 3 gets the next free number rather than forcing a renumbering of Tiers 1–2 across all existing docs, ADRs, and session prompts. Every tier-comparison table must therefore order rows by guarantee strength, not tier number, to avoid implying Tier 3 is "above" the others.

## Decision

Add **Tier 3: Handoff Mode** — a temporary, parent-supervised containment mode that locks the Covelight child experience to the foreground of the parent's own phone.

- **Android:** implemented inside the existing Covelight companion/kiosk codebase via consumer screen pinning. One-tap "Hand to child" entry; exit via the OS gesture (Back + Recents held together) gated by the parent's lock screen credential.
- **iOS:** deferred to a separate go/no-go decision (see Option C and Action Items). If pursued, it relies on Apple's Guided Access (triple-click side button; exit via triple-click + passcode/Face ID) and bundles content inside the app, updated through App Store releases.

Tier 3 is marketed strictly as *"lend your phone safely for twenty minutes"* — never as a kiosk, never as locked-down, never as air-gapped.

## Options Considered

### Option A: Do nothing (Tiers 1–2 only)

| Dimension | Assessment |
|-----------|------------|
| Complexity | None |
| Adoption impact | Poor — misses the most common first-contact scenario |
| Constraint risk | None |
| Maintenance | None |

**Pros:** Zero scope creep; tier story stays maximally simple; no risk of guarantee dilution.
**Cons:** Parents who hand over their phone (the majority use case in practice) get nothing; the strongest adoption funnel entry point is left on the table; competitors' "kid mode" features fill the gap.

### Option B: Android-only Handoff Mode (recommended now)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low — `startLockTask()` + one settings-guidance flow, inside the existing app |
| Adoption impact | High — one-tap trial on any Android 8+ phone |
| Constraint risk | Low, provided labeling rules are enforced |
| Maintenance | Low — consumer screen pinning is a stable API |

**Pros:** Minimal new code; no new distribution channel; content pipeline unchanged (same Godot shell, same signed PCKs, synced to the parent's phone by the companion flow); natural upsell path to Tier 1.
**Cons:** Interruptible by incoming calls; defeated by a child who knows the parent's PIN; requires a one-time Settings toggle by the parent.

### Option C: Android + iOS Handoff Mode

| Dimension | Assessment |
|-----------|------------|
| Complexity | High — new platform, new build/signing pipeline, Apple Developer account, App Store review |
| Adoption impact | Highest — reaches iPhone households, a large share of the target audience |
| Constraint risk | **Medium-high** — touches "No OTA content to the child app" and possibly "One Godot runtime" |
| Maintenance | Ongoing — App Store policy churn, annual fees, review cycles |

**Pros:** Guided Access is a mature, well-understood parental feature; content-in-bundle sidesteps the USB restriction that originally excluded iOS.
**Cons:**
- No programmatic entry: `UIAccessibilityRequestGuidedAccessSession` works only on MDM-supervised devices, so there is no one-tap button — the app can only *detect* Guided Access and display a handoff state.
- App Store updates are, mechanically, OTA content delivery. Deciding whether "parent-mediated App Store update" is an acceptable reinterpretation of the *No OTA content to the child app* constraint, or a violation of it, is a constitutional question for the project and must not be decided implicitly.
- Godot-on-iOS packaging and PCK signing verification inside an App Store binary need their own validation.
- Non-profit budget must absorb the $99/year developer fee and review overhead.

## Trade-off Analysis

The core trade-off is **adoption reach vs. constraint integrity.**

Option B buys most of the adoption value at almost no constraint risk: the Android app already exists, the content pipeline is unchanged, and screen pinning's weaknesses can be honestly labeled. Option C's incremental reach is real but reopens a settled architectural exclusion (iOS) and forces a reinterpretation of an inviolable constraint (no OTA). That decision deserves its own ADR with a cooling-off period, not a rider on this one.

The secondary trade-off is **guarantee dilution.** Every new, weaker tier risks blurring what "Covelight" means. Mitigation is structural: Tier 3 gets its own vocabulary ("Handoff Mode", "containment", "convenience"), a mandatory in-app disclosure of its limits, and a hard ban on Tier 1/2 terminology — enforced via CLAUDE.md so no future session drifts.

## Consequences

**Easier:**
- First contact: any Android parent can try Covelight tonight, on the phone in their pocket.
- Marketing: "No phone on Earth was built for a child — but yours can pretend for twenty minutes" is a natural follow-up post.
- Upsell: the in-app limits disclosure doubles as the pitch for Tier 1 ("want this without the caveats? that old phone in your drawer…").

**Harder:**
- Tier communication: three tiers where the numbering doesn't match guarantee strength requires disciplined tables and copy everywhere.
- Support surface: screen pinning UX varies subtly across OEM skins (Samsung, Xiaomi); expect device-specific guidance in `docs/devices/`.
- Testing: incoming-call interruption behavior and unpin-credential flows need per-OEM verification.

**To revisit:**
- iOS go/no-go (separate ADR) once Tier 3 Android ships and demand is measurable.
- Whether Tier 3 sessions should have a parent-set soft time limit (a wind-down cue, not a dark pattern — must be reviewed against the attention-engineering ban).

## Action Items

1. [ ] Renumber this ADR and commit to `docs/decisions/`
2. [ ] Commit `docs/design/tier3-handoff-mode.md` (UX + technical design)
3. [ ] Add Tier 3 constraints block to `CLAUDE.md` (see `tier3-doc-updates.md`)
4. [ ] Update `ARCHITECTURE.md` and `README.md` tier tables (ordered by guarantee strength)
5. [ ] Add Phase task(s) for screen-pinning implementation + OEM test matrix
6. [ ] Draft (do not decide) the iOS ADR skeleton with the OTA-constraint question stated explicitly
