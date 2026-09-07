# Tier 3 — Updates to Existing Docs

> This file is a paste-ready checklist, not a doc to commit as-is. Apply each block, then delete this file.

## 1. CLAUDE.md — add to the tier model section

```markdown
### Tier 3: Handoff Mode (parent's own phone)

Temporary containment of the child experience on the parent's daily-driver phone.
- Android: consumer screen pinning (`startLockTask()`, non-Device-Owner). Entry: one tap. Exit: Back+Recents hold → parent's lock screen credential.
- iOS: NOT approved. Requires its own ADR resolving the OTA-constraint question first. Do not write iOS code.

Tier numbers reflect deployment model, NOT guarantee strength.
Guarantee strength: Tier 2 > Tier 1 > Tier 3. Order all comparison tables by strength.
```

## 2. CLAUDE.md — add to inviolable constraints

```markdown
- Tier 3 is never described as "kiosk", "locked down", "air gap", "secure", or "childproof". Permitted register: "handoff", "containment", "convenience".
- Tier 3 sessions require a device lock screen credential and the "ask for PIN before unpinning" toggle; refuse to start otherwise.
- Tier 3 must show the limits disclosure before first session (interruptible by calls; defeated by knowing the parent's PIN; not the kiosk).
- Signature verification runs on every tier: unsigned content never loads, including when shell and companion are co-resident on the parent's phone.
- Session wind-down cues must pass attention-engineering review: no countdowns, no alarms, no stats, no streaks, no re-engagement prompts.
```

## 3. ARCHITECTURE.md — tier table replacement

Replace the two-tier table with a strength-ordered three-tier table (copy from `docs/design/tier3-handoff-mode.md` §"What Tier 3 is").

## 4. README.md

- Add one paragraph under the tier overview: Handoff Mode as the zero-commitment entry point.
- Do not use forbidden vocabulary (see constraint block above).

## 5. docs/plan/ — new tasks (suggested numbering; adjust to current phase plan)

```markdown
### T-HM.1 — Screen pinning session manager (Android)
startLockTask entry, unpin detection, credential-toggle preflight, refuse-without-lockscreen guard.

### T-HM.2 — First-run flows
Settings deep-link guide (per-OEM paths), limits disclosure screen, one-time state persistence.

### T-HM.3 — Child UI handoff
Co-resident shell launch on parent phone; verify PCK signature check runs identically to Tier 1.

### T-HM.4 — Wind-down cue (design first)
Design + attention-engineering review BEFORE implementation. Blocked on review sign-off.

### T-HM.5 — OEM verification matrix
Pixel, Samsung One UI, Xiaomi HyperOS: pin survival, call interruption behavior, unpin credential flow. Results committed to docs/devices/.
```

## 6. docs/decisions/

- Commit `ADR-XXX-tier3-handoff-mode.md` (renumber).
- Create a *skeleton only* for the iOS ADR with the OTA question stated verbatim; status: Proposed, decision deliberately deferred.

## 7. Claude Code session prompts

Write session prompts for T-HM.1–T-HM.3 following the existing per-task prompt pattern; include the Tier 3 constraint block verbatim in each prompt's context section.
