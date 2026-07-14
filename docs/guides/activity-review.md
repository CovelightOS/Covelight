# Activity Review Checklist

**Status:** Accepted · written for T1.3 (`docs/plan/02-phase1-shell.md`).
This is what turns CLAUDE.md constraints #1 (textless) and #4 (no
attention engineering) — and #5/#10 (no network) — into things a reviewer
checks and answers yes/no, not things they take on faith. Every item below
maps to a specific rule in `docs/design/activity-sdk.md`; read that first
if a check doesn't make sense on its own.

Run the two mechanical checks first — they're fast and catch the most
common mistakes before you even open the activity:

```sh
tools/lint_activity.sh activities/<the_activity>
godot --headless --path activities/<the_activity> --import
godot --headless --path activities/<the_activity> -s addons/gut/gut_cmdln.gd -gexit
```

Neither is sufficient on its own (both have stated honest limitations —
`docs/design/activity-sdk.md` §12, `shell/sdk/text_audit.gd`'s own doc
comment) — they narrow what you have to check by hand below, they don't
replace looking.

## Textless (constraint #1)

- [ ] `tools/lint_activity.sh` reports clean, or every hit is reviewed and
      is a genuine false positive (e.g. a comment, not a live node)
- [ ] The activity's GUT suite includes a `TextAudit.find_text_nodes(...)`
      assertion against the instantiated scene, and it passes
- [ ] You ran the activity (`godot --path activities/<the_activity>`) and
      looked — no string, label, tooltip, or dialog is visible in any
      reachable state, including the "wrong tap" / redirect state
- [ ] No text is baked into an image asset (a word drawn into a sprite) —
      the lint script and `TextAudit` cannot catch this; check by eye

## Audio-first (constraint #1)

- [ ] Every piece of guidance or feedback the child receives is a sound,
      not a visual score/checkmark/text-adjacent icon standing in for one
- [ ] Sound is routed through `ActivityAudio` (`play_cue` /
      `play_gentle_redirect`), not a raw `AudioStreamPlayer` scattered
      elsewhere — needed so T1.7's real bus/ducking system reaches every
      cue uniformly

## No attention engineering (constraint #4)

- [ ] No score, streak, level, or leaderboard of any kind, anywhere
- [ ] No "play again?" prompt or any other replay-pressure loop after
      `report_finished()` — the shell's own return-to-home is the only
      thing that happens next
- [ ] No variable/random reward (a cue or animation that sometimes is
      "better" than other times for the same action)
- [ ] No autoplay chain — the activity doesn't queue up "next" content on
      its own
- [ ] No timer that pressures continued play (a countdown, a "hurry up"
      cue). A timer used purely for internal pacing (e.g. the template's
      calm end-delay) is fine; a timer the child feels pressure from is not

## No failure states (constraint #4)

- [ ] A "wrong" action never plays a negative-affect sound (no buzzer, no
      descending "fail" tone, nothing that reads as rejection)
- [ ] A "wrong" action never restarts progress, ends the activity, or
      changes state in any way the child would need to recover from — see
      the template's `DistractorShape` for the reference shape of this
- [ ] Silence is never the only response to an action — every tap, on
      target or not, produces *some* audio acknowledgment

## Calm endings (constraint #4)

- [ ] `report_finished()` is called exactly once per session, at a natural
      stopping point, never mid-interaction
- [ ] Nothing happens between the last meaningful action and
      `report_finished()` except the activity's own brief, calm wind-down
      (if any) — no screen demanding one more tap first

## Input (safe margin + minimum touch target)

- [ ] Every interactive element is inset at least
      `LayoutConstants.SAFE_MARGIN` from every screen edge it's near
- [ ] Every `TouchTarget`/`Draggable` is at least
      `LayoutConstants.MIN_TOUCH_TARGET_SIZE` in *actual on-screen size* —
      check the real rendered size, not just that no warning was logged
      (a parent container or explicit offset can still shrink it past
      what the default alone would prevent)
- [ ] Both checked at all layouts the manifest declares (below), not just
      the one you happened to preview in

## Manifest and responsive layout (mandatory declaration)

- [ ] `manifest.cfg` has `id`, `version`, `min_shell_version`, a non-empty
      `declared_layouts`, and `entry_scene` — `ActivityManifest.load_from_file()`
      reports it valid
- [ ] The activity was actually run and visually checked at every layout
      listed in `declared_layouts` (`phone_portrait`, `tablet_portrait`) —
      a declared-but-unverified layout is worse than an honestly narrower
      declaration
- [ ] No orientation logic anywhere — activities are portrait-only, always
      (`docs/design/activity-sdk.md` §9); if you find orientation-branching
      code, that's a sign of copying from something other than the current
      template

## No network, no telemetry (constraints #5 / #10)

- [ ] `tools/lint_activity.sh` reports no network-class hits, or every hit
      is reviewed and genuinely inert (e.g. a comment)
- [ ] No calls into `ActivityProgress` (or anything else) that leave the
      device — everything it touches is `user://`, nothing else
- [ ] No third-party SDK, plugin, or `addons/` entry beyond
      `covelight_sdk` and `gut` (dev-only) is present

## Manifest-declared min shell version

- [ ] `min_shell_version` is set honestly to the lowest shell version this
      activity actually depends on, not copy-pasted from the template
      without checking
