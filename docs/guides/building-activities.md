# Building a Learning Activity

**Audience:** you, if you want to build a Covelight learning activity and
have never opened Godot before. **Target:** a working, reviewable activity
in a weekend.

This guide is the practical walkthrough. Two documents it leans on heavily
and doesn't repeat:

- **`docs/design/activity-sdk.md`** — the actual contract (manifest format,
  lifecycle, every API call available to you). Read it once you've copied
  the template below; this guide tells you *when* to reach for which part
  of it, not what every field means.
- **`docs/guides/activity-review.md`** — the checklist a maintainer runs
  before signing your activity. Nothing here should surprise you if you've
  read that.

If you've never touched Godot at all: this project assumes you know the
basics (scenes, nodes, signals, GDScript) from Godot's own docs
(`docs.godotengine.org` → "Step by step" tutorial, an hour or two). Nothing
below re-teaches those — it's about *this project's* activity contract,
not the engine.

## 1. Setup: clone → running shell

Prerequisites, once: the Godot 4.7 editor (`brew install --cask godot` or
godotengine.org), a Rust toolchain (rustup.rs), and `just`
(`brew install just` or github.com/casey/just).

```sh
git clone <this-repo-url> && cd covelight
just run
```

That's it — two commands, and you're looking at the actual shell a child
would see (textless, sound-driven, home screen with the existing
activities on it). `shell/README.md` has the details of what `just run`
does under the hood and the manual command equivalents if you'd rather not
install `just`.

Run the existing test suite too, so you know what "all green" looks like
before you add anything of your own:

```sh
just test
```

This runs the shell's own tests plus every existing activity's — it's slow
the first time (building the T1.4 GDExtension from scratch) and fast every
time after.

## 2. Copy the template

Every activity is its own small Godot project, sibling to `_template`
under `/activities/`. Don't start from a blank Godot project — copy the
one that already has the contract wired up:

```sh
cp -r activities/_template activities/your_activity_name
cd activities/your_activity_name
ln -sf ../../../shell/sdk addons/covelight_sdk       # if cp didn't preserve symlinks
ln -sf ../../../shell/addons/gut addons/gut           # same
```

Preview it standalone right away, before changing anything, so you know
the baseline works on your machine:

```sh
godot --headless --path . --import   # once, registers class_name globals
godot --path .                        # a real window: two shapes, tap either
```

Tap the shape in the bottom-right (green) — you hear a tone, then the
activity ends calmly after a second. Tap the other one (yellow) — a
different, gentler tone, and nothing else happens. That's the whole
contract in miniature: **one path that's "the answer," which ends the
activity calmly; every other tap gets a soft acknowledgment and changes
nothing.** Your real activity is a richer version of exactly this shape.

Now make it yours:

1. **`manifest.cfg`** — set `id` to something stable (this becomes your
   `.pck`'s filename, and the key your progress data is stored under —
   don't change it after publishing). Fill in `declared_layouts` honestly
   once you've actually checked your layout at each one (§5 below).
2. **`activity.tscn` / `activity.gd`** — replace the two demo shapes with
   your real activity, keeping `extends "res://addons/covelight_sdk/activity_base.gd"`
   (by path, not `extends ActivityBase` — `docs/design/activity-sdk.md` §4
   explains why).
3. **Every interactive element** — inset at least `LayoutConstants.SAFE_MARGIN`
   from any screen edge, and at least `LayoutConstants.MIN_TOUCH_TARGET_SIZE`
   in actual on-screen size. `TouchTarget`/`Draggable` default to the
   minimum size; the edge inset is on you.
4. **Your own tests** — `tests/test_activity_template.gd` is the pattern
   to copy. Keep it running as you go, not just at the end:

```sh
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

Or, from the repo root: `just test-activity your_activity_name`.

## 3. The SDK contract, in the order you'll actually use it

Full detail in `docs/design/activity-sdk.md`; here's the order a typical
build touches it:

- **Lifecycle** (§4): call `report_ready()` once your scene can take
  input, `report_finished()` once, at a calm natural stopping point. These
  are the only two calls that matter for "does my activity load and end
  correctly" — get them right first, before any real content.
- **Audio** (§5): `ActivityAudio.play_cue(stream)` for anything the child
  should hear, `play_gentle_redirect(stream)` for the "that wasn't it"
  case. `play_placeholder_tone(hz, seconds)` lets you build and test your
  activity's *timing* before you have real sound assets — exactly what the
  template itself uses. There is no text/caption parameter anywhere on
  this API; that's not a gap, it's the point (§4 below).
- **Input** (§6): `TouchTarget` for tap/hold, `Draggable` (extends
  `TouchTarget`) for drag-and-drop with real multi-touch support. Both
  enforce `LayoutConstants.MIN_TOUCH_TARGET_SIZE` on their own minimum
  size — you're responsible for keeping them away from
  `LayoutConstants.SAFE_MARGIN`'s edge zone.
- **Progress** (§7, optional): `ActivityProgress.load_progress(id)` /
  `save_progress(id, dict)` if your activity wants to remember anything
  between sessions (e.g. "which animals has the child heard"). Local-only,
  opaque to everything outside your own activity — there is no shared
  schema and no way for this to leave the device.

## 4. Designing for pre-literate children

This is the part that isn't a Godot question at all, and it's where most
of the actual design work lives. Two rules from `CLAUDE.md` shape
everything:

**No text, anywhere the child can reach (constraint #1).** Not "avoid
text" — there is no text-rendering call anywhere on the SDK surface to
reach for. Every piece of guidance or feedback is a sound, an animation,
a color, a shape. If you catch yourself wanting a checkmark icon or a
"good job" popup, that's the same instinct as wanting a word — find the
sound or motion that does the same job instead.

**No attention engineering, ever (constraint #4).** Concretely, for an
activity:

- **No score, streak, level, or leaderboard.** Not a small one either.
- **No failure states.** There is no wrong answer, only redirection — a
  mis-tap gets `play_gentle_redirect()` and nothing else changes. Never
  silence (silence reads as rejection to a small child), never a
  negative/buzzer sound, never a restart-from-scratch. The template's
  `DistractorShape` is the reference shape of this — copy its pattern, not
  just its idea.
- **No "play again?" prompt or replay-pressure loop.** `report_finished()`
  just ends. The shell's own fade back to the home screen is the only
  thing that happens next, every time, win or otherwise — there is no
  "otherwise."
- **No variable/random reward.** The same action should feel the same
  every time, not sometimes-better as a hook to keep tapping.
- **No autoplay chain and no pressuring timer.** A timer used purely for
  your own pacing (like the template's one-second calm-end delay) is
  fine; a countdown or "hurry up" cue is not.

**In practice, this is easier than it sounds** — the SDK genuinely doesn't
offer you the pieces that would violate any of this. If you're only using
`ActivityAudio`, `TouchTarget`/`Draggable`, and `ActivityProgress`, you get
a compliant activity by construction, not by remembering a rulebook.

**Two more things worth designing for, not required by any API but real:**

- **Calm pacing.** Slower than instinct suggests. A toddler needs longer
  than you do to notice a cue landed and decide what to do next.
- **Forgiving hitboxes.** `MIN_TOUCH_TARGET_SIZE` is a floor, not a
  target — bigger, especially for a first activity, is more forgiving of
  the motor control this age group actually has.

## 5. Testing across form factors

Every activity is portrait-only, always (`docs/design/activity-sdk.md`
§9) — there's no orientation logic to write. What still varies is the
portrait canvas's *shape*: a tall narrow phone vs. a squarer tablet.
`manifest.cfg`'s `declared_layouts` is where you say which shapes you
actually checked (`phone_portrait`, `tablet_portrait`) — an empty list
fails validation, and a declared-but-unverified layout is worse than an
honestly narrower one.

Check your own activity standalone at both — `phone_portrait` is the
shell's own base resolution; `tablet_portrait` is that same 4:3 tablet
ratio the shell simulates (`just run tablet`, 2048×1536), portrait
(width/height swapped):

```sh
godot --path activities/your_activity_name --resolution 1080x2340   # phone_portrait
godot --path activities/your_activity_name --resolution 1536x2048   # tablet_portrait
```

And check it loaded inside the actual shell, from the repo root, at all
three of the shell's own reflow ratios (this exercises the shell's
`canvas_items`/`expand` stretch behavior around your content, not just
your activity's own layout):

```sh
just run                  # phone-portrait, default
just run phone-landscape
just run tablet
```

(You won't see your own unsigned activity on the shell's home screen yet —
that list is hard-coded to the currently-signed set. This step is about
confirming the *shell itself* still reflows correctly, which matters once
your activity is merged and signed.)

Headless mode (`--headless`) has no real window, so it can't tell you
anything about layout — use it only for the class-registration `--import`
step and for running tests, never to judge how something actually looks.

## 6. Review checklist and submission

Before opening a PR, run the two mechanical checks — fast, and they catch
the most common mistakes before a human has to look:

```sh
tools/lint_activity.sh activities/your_activity_name
just test-activity your_activity_name
```

Then work `docs/guides/activity-review.md`'s full checklist yourself,
honestly — it's the same list a maintainer runs, and it exists so you
never have to guess whether something is "textless enough" or "calm
enough." Every item maps to a concrete check, not a feeling.

**Submission** follows `CONTRIBUTING.md`'s normal flow: one branch, one PR,
named after your activity. You're submitting **source only** — you don't
need (and as a contributor, won't have) the project's Ed25519 signing key.
A maintainer builds, signs, and merges your activity as the actual publish
step (`docs/design/activity-sdk.md` §10); your job is a working, reviewed
source tree that passes the checklist above. Signing attests provenance,
not review compliance (`docs/design/signing.md`) — the checklist is what
actually earns the review, the signature is what makes the shell trust the
bytes afterward.

That's the whole loop: copy the template, build against the SDK, test at
both layouts, run the checklist, open a PR. Nobody needs to unblock you
for any of it.
