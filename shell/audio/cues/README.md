# Placeholder cue set — replaceable by design

Every sound the shell itself plays (as opposed to sounds an individual
activity plays through its own `ActivityAudio`) is looked up by name
through `CueLibrary.get_cue()` (`shell/audio/cue_library.gd`). Today none
of the files this README describes exist, so every cue is a short
procedural sine tone generated on the fly — audibly fine, but not real
sound design.

**Real sound design is a contributor lane, not this task's job.** T1.7
only had to make the swap trivial. It is:

1. Record or license a short, calm sound (see "What 'calm' means" below).
2. Export/convert it to `.ogg` or `.wav`.
3. Drop it in this directory named exactly after the cue it replaces —
   e.g. `ui_tap.ogg`.
4. Delete nothing, change no code. `CueLibrary.get_cue("ui_tap")` checks
   this directory first and only falls back to the procedural tone if
   nothing's here.

## Current cue names and what triggers them

| Cue name | Triggered by | Placeholder tone |
|---|---|---|
| `ui_tap` | `HomeTile` tap (immediate, before anything else happens) | 660 Hz, 0.12s |
| `ui_hold_preview` | `HomeTile` hold-to-preview | 440 Hz, 0.4s |
| `transition_leave` | `TransitionOverlay.cover()` — leaving the current screen | 330 Hz, 0.35s |
| `transition_arrive` | `TransitionOverlay.reveal()` — arriving at the next screen | 440 Hz, 0.3s |
| `gentle_redirect` | generic shell-level soft redirect (not activity-specific) | 392 Hz, 0.25s |

(This table must stay in sync with `CueLibrary._PLACEHOLDER_TONES` — if
you add a cue there, add it here too.)

## What "calm" means for this project (CLAUDE.md #1, #4)

- No stings, jingles, or anything that reads as a reward/alert. This is
  the primary channel a pre-literate child uses to understand the UI —
  it has to feel as neutral and unremarkable as a door closing, not like
  a game show buzzer.
- Short. Under ~0.5s for interaction feedback; nothing loops or repeats.
- No two cues should be confusable with a "wrong"/negative sound — there
  are no failure states in this project (constraint #4), and that
  includes the shell chrome, not just activity content.
- If in doubt, quieter and shorter is the safer default.

## Why activity-authored cues aren't here

An activity's own sounds (an animal noise, a "try again" redirect) are
the activity's own asset, loaded and played through its own
`ActivityAudio` node (`docs/design/activity-sdk.md` §5) — those ship
inside that activity's `.pck`, not in this shared directory. This
directory is only for sounds the *shell itself* plays, independent of
whichever activity (if any) is running.
