# Activity SDK Contract

**Status:** Accepted · written for T1.3 (`docs/plan/02-phase1-shell.md`),
before any real activity is built. `/activities/_template` is this
document's executable companion — copy it, don't start from a blank Godot
project. If anything here and the template ever disagree, the template
lost a sync, not the other way around; file that as a bug.

**Audience:** anyone building a Covelight learning activity — deliberately
written so a contributor with no prior Godot experience and no access to
`/shell` source can build a working activity from this document alone.
Godot's own docs (godotengine.org) cover engine basics (scenes, nodes,
signals, GDScript) this document doesn't re-teach.

## 1. What you're building, in one paragraph

An activity is a small, independent Godot 4 project that exports to a
signed `.pck` bundle. The Covelight Shell loads it, instantiates its entry
scene, and drives it through a four-call lifecycle. Everything the child
experiences is animation, touch, and sound — this SDK's API surface
reflects that literally: there is no text-rendering call anywhere in it to
reach for, no network call, no score/streak persistence call. The safe,
calm, textless path is the *only* path the API offers.

## 2. Project layout

Every activity is its own Godot project, sibling to `_template` under
`/activities/`:

```text
activities/<your_activity>/
  project.godot          # local preview only -- see §2.1
  export_presets.cfg      # produces the .pck; excludes project.godot itself
  manifest.cfg            # §3
  activity.tscn            # entry scene, root extends ActivityBase
  activity.gd
  addons/
    covelight_sdk/         # symlink -> ../../../shell/sdk  (read-only, don't edit here)
    gut/                    # symlink -> ../../../shell/addons/gut (for your own tests)
  tests/                    # your GUT tests, see _template/tests
```

Start by copying `/activities/_template` wholesale and renaming the
directory and `manifest.cfg`'s `id`. The two `addons/` entries are
symlinks, not copies — recreate them if your OS/tool doesn't preserve
symlinks on copy:

```sh
cd activities/<your_activity>
ln -s ../../../shell/sdk addons/covelight_sdk
ln -s ../../../shell/addons/gut addons/gut
```

**Why symlinks, not a copy of the SDK per activity:** Godot has no
cross-project dependency mechanism — a project can only load resources
under its own `res://` root. A symlink makes the *same physical files*
appear under every activity's `res://` at once, so an SDK fix or addition
(ADR 0002's "ecosystem-wide events") lands everywhere by editing one file
in `/shell/sdk`, not by hand-syncing N copies. Godot's exporter reads
through symlinks like any other file when it packs a `.pck`, so this costs
nothing at export time.

**Accepted cost:** git symlinks work natively on macOS/Linux (this
project's documented dev environments — ARCHITECTURE §7). On Windows,
`git config core.symlinks true` plus Developer Mode (or an elevated
prompt) is needed before the symlinks materialize on checkout; without
that they check out as small text files containing a path, and nothing
will load. Stated here rather than hidden — file an issue if this is a
real blocker for you and it'll get prioritized.

### 2.1 `project.godot` is a preview convenience, not shipped config

Your activity's `project.godot` exists so you can run and preview the
activity standalone (`godot --path activities/<your_activity>`) without
the shell. When the shell loads your exported `.pck`, it does **not**
re-apply your project's renderer, window, or stretch settings — those are
fixed once, at the shell's own startup (GL Compatibility renderer,
1080×2340 base, `canvas_items`/`expand`, portrait-locked — `shell/README.md`
"Renderer + stretch"). Your scene inherits the shell's already-running
viewport. Set your own `project.godot` to mirror the shell's settings
anyway (the template already does) purely so what you see while previewing
matches what the child will actually see.

Because it's never read at runtime, **`export_presets.cfg` excludes
`project.godot` from the packed `.pck`** (the template's does, via
`exclude_filter`) — shipping it is dead weight, not a functional bug, but
dead weight is still a bug in an unfunded volunteer project. Verified
directly (`docs/research/godot-pck.md`): a real `--export-pack` run
confirms the source `project.godot` file is excluded. One caveat found by
the same test, not from documentation: Godot's exporter always writes a
compiled `res://project.binary` into the pack regardless of `exclude_filter`
— an internal artifact of the export pipeline, not something this SDK can
suppress. Whether `load_resource_pack()` merges anything from it into the
shell's already-running settings is unconfirmed as of this document; T1.4
(real signed-PCK loading) must check this directly against the engine
before it ships, not assume either way.

## 3. The manifest (`manifest.cfg`)

A plain Godot `ConfigFile` — deliberately *not* a custom `Resource`
subclass. A `.pck` loaded at runtime via `load_resource_pack` is never
scanned into the host shell's global `class_name` cache (see
`docs/research/godot-pck.md`), so a custom class defined inside your
activity's own PCK wouldn't reliably resolve on the shell's side. A
`ConfigFile` is a built-in engine type, always available, in both
directions — no registration step to get wrong.

```ini
[activity]
id = "animal_sounds"
version = "0.1.0"
min_shell_version = "0.1.0"
declared_layouts = ["phone_portrait", "tablet_portrait"]
entry_scene = "res://activity.tscn"
```

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Stable identifier, matches the exported `<id>.pck` filename and the id `tools/sign` signs. Never changes once published — it's also the key `ActivityProgress` stores under. |
| `version` | yes | Your activity's own version, semver-ish (`major.minor.patch`). Yours to bump; the shell doesn't interpret it beyond display/logging. |
| `min_shell_version` | yes | Lowest shell `config/version` (`shell/project.godot`) this activity requires. Compared as dotted integers by `ActivityManifest.is_compatible_with_shell()` — not a security boundary, just avoids handing an old shell an activity that assumes a newer SDK surface. |
| `declared_layouts` | yes, non-empty | Which portrait-shaped canvases you've verified your layout against. Values: `phone_portrait`, `tablet_portrait` (§9 — there is no landscape value; activities don't declare orientation, they're always portrait). "Responsive layout declaration is mandatory" (T1.3 acceptance) means exactly this: an empty list fails validation. |
| `entry_scene` | no (defaults shown) | `res://` path to your root scene, by SDK convention always `res://activity.tscn`. Present explicitly so tooling can validate it rather than assume it. |

Load and validate it yourself with `ActivityManifest.load_from_file(path)`
(`shell/sdk/activity_manifest.gd`) — the same code the shell's own tooling
uses, so what passes in your own tests is what passes on the shell side.

## 4. Entry point & lifecycle

Your `activity.tscn` root is a `Control` that extends the SDK's base
contract **by path**, not by global class name:

```gdscript
# activity.gd
extends "res://addons/covelight_sdk/activity_base.gd"

func _ready() -> void:
    report_ready()
    # ... set up your scene, connect your TouchTargets, etc.

func _on_finished() -> void:
    report_finished()
```

Path-based `extends` (not `extends ActivityBase`) is deliberate: Godot's
`class_name` global registry is built by an editor-mode scan of *your own*
project the first time it's opened (`shell/README.md` documents the same
gotcha for the shell itself — a fresh checkout run headless, without that
scan, fails in a way that's easy to misdiagnose). A path-based `extends`
needs no such scan; it just works, on a fresh clone, in CI, every time.

Four lifecycle points, in order:

1. **start** — call `report_ready()` from `_ready()` (or later, once
   actually able to take input) once, when your activity has finished
   setting up. The shell is watching for this signal with a timeout
   (`Shell.load_timeout_seconds`, 5s default) as its *only* signal that
   loading succeeded — never calling it looks identical, to the shell, to
   crashing or hanging, and after the timeout it calmly returns to home
   with no error shown to the child. This is intentional crash containment
   (T1.2), not a bug you need to work around.
2. **pause** — override `_on_activity_paused()` if you have animations or
   audio that should stop when the shell/app loses OS focus (backgrounded,
   interrupted). No-op by default; most activities can ignore it.
3. **resume** — override `_on_activity_resumed()` to undo whatever pause
   did. No-op by default.
4. **end** — call `report_finished()` when the activity is done and the
   child should return home. This is the *only* way an activity ends —
   there's no separate "quit" or "back" signal, because there's no
   child-reachable quit path anywhere in this project (`shell/shell.gd`).
   Call it calmly: after a natural stopping point in the activity, never
   as a response to a "wrong" action (§8).

## 5. Audio API

`ActivityAudio` (`shell/sdk/audio_cue.gd`) is the one Node type your
activity should ever play a sound through:

```gdscript
@onready var _audio: ActivityAudio = $ActivityAudio

func _on_shape_tapped() -> void:
    _audio.play_cue(preload("res://sounds/moo.ogg"))

func _on_wrong_shape_tapped() -> void:
    _audio.play_gentle_redirect(preload("res://sounds/try_again_soft.ogg"))
```

`play_cue(stream)` is the generic entry point. `play_gentle_redirect(stream)`
is behaviorally identical — it exists so "what do I call when the child
tapped the wrong thing" has an obviously-named, correctly-shaped answer
sitting right there in the API, nudging toward §8's "no failure states"
rule instead of leaving you to invent your own naming. Which *sound* you
pass it is still your call, and review checks it (never a buzzer, never
anything that reads as negative).

`play_placeholder_tone(hz, seconds)` generates a short procedural sine
tone — for prototyping your activity's *timing and structure* before real
audio assets exist, the same role `transition_overlay.gd`'s placeholder
tone plays for shell chrome. It never ships in a reviewed activity;
placeholder cue sets are explicitly documented as replaceable (T1.7).

There is no text, caption, or subtitle parameter anywhere on this API.
Not discouraged — absent. An activity that wants to tell the child
something has exactly one tool: a sound.

`ActivityAudio` routes to Godot's default `"Master"` bus for now; T1.7
adds the real central bus (ducking, cue library, volume persistence) by
changing this one file, not by touching any activity.

## 6. Input API

### Safe margin

No interactive element — `TouchTarget`, `Draggable`, or anything else —
may sit closer than `LayoutConstants.SAFE_MARGIN` (120.0 project units,
~0.3in physical at the 1080-wide base) to any screen edge. Small children
rest their thumbs on a device's physical edge; this is the exclusion zone
that keeps a resting thumb from accidentally triggering something. Anchor
every interactive node inset by at least this much — `shell/scenes/home.tscn`
is the worked reference for anchor placement at this margin.

### Minimum touch target size

`LayoutConstants.MIN_TOUCH_TARGET_SIZE` (160.0 units, ~0.4in physical) —
deliberately larger than adult-hand accessibility minimums (WCAG 2.2 AAA
~44px, Android Material 48dp, both ≈0.3in) because pre-literate children
have coarser motor control than either guideline assumes. `TouchTarget`
raises its own `custom_minimum_size` to this floor (so a container-sized
target gets it for free), and separately checks its *actual* on-screen
size one frame after entering the tree — most shapes here are sized by
anchors/offsets, not `custom_minimum_size`, so only checking the latter
would miss a visibly-too-small shape. Either path below the floor prints a
loud warning; this is a design estimate, not a measured one — T1.5's "hand
it to an actual small child" check is the real validation, and this
constant may move as a result.

### `TouchTarget` — tap and hold

```gdscript
@onready var _cow: TouchTarget = $Cow

func _ready() -> void:
    _cow.tapped.connect(_on_cow_tapped)
    _cow.held.connect(_on_cow_held)   # e.g. audio preview on hold, T1.5's home screen pattern
```

Handles both `InputEventScreenTouch` (device) and `InputEventMouseButton`
(desktop dev) so behavior is identical in the editor and on a real phone.
Signals: `tapped`, `held` (after 0.5s), `released`.

### `Draggable` — drag and drop, multi-touch

`Draggable extends TouchTarget`, adding `drag_started(index, position)`,
`drag_moved(index, position)`, `drag_ended(index, position)` — `index` is
the OS touch-slot index (or `Draggable.MOUSE_INDEX` for desktop), so
several `Draggable`s can each be mid-drag under different fingers
simultaneously with no extra bookkeeping — this is what makes a two-finger
color-mixing interaction possible without a bespoke multi-touch system per
activity. See the module's own doc comment
(`shell/sdk/draggable.gd`) for why it listens on `_input()` rather than
`_gui_input()` (so a drag survives leaving the target's own rect) and for
its one honest limitation (tightly overlapping `Draggable`s can both
"catch" the same initial touch — not a concern at `SAFE_MARGIN` spacing).

## 7. Progress storage

`ActivityProgress` (`shell/sdk/activity_progress.gd`) is local-only,
per-activity, opaque:

```gdscript
var progress := ActivityProgress.load_progress(MANIFEST_ID)  # {} if none yet
progress["times_completed"] = progress.get("times_completed", 0) + 1
ActivityProgress.save_progress(MANIFEST_ID, progress)
```

One `Dictionary` blob per activity `id`, under `user://progress/<id>.cfg`.
Your activity decides its own shape and is the only code that ever reads
it back — there is no shared cross-activity schema (deliberate, provisional:
`docs/plan/02-phase1-shell.md`'s open question, "start opaque, revisit at
Phase 4" when `syncd` may want to surface progress to parents). There is
no network call anywhere in this file, or reachable from it, or reachable
from anything else in `/shell/sdk` — CLAUDE.md #5/#10 isn't a rule the SDK
asks you to follow, it's a rule the SDK's own surface makes impossible to
break by using only what's offered.

## 8. Hard SDK rules

- **Textless.** No `Label`, `RichTextLabel`, `Button` (or any other
  text-bearing control — see `TextAudit`'s full list), no captions, no
  score display, anywhere the child can reach.
- **Calm endings.** No score screens, no streaks, no "play again?"
  prompts, no variable rewards, no timer pressuring continued play.
  `report_finished()` just ends — the shell fades to home the same calm
  way every time, win or otherwise (there is no "otherwise": see next).
- **No failure states.** There is no wrong answer, only redirection. A
  mis-tap gets `play_gentle_redirect()` and nothing else — never silence
  that reads as rejection, never a negative-affect sound, never a
  restart-from-scratch.
- **Responsive layout declaration is mandatory.** `manifest.cfg`'s
  `declared_layouts` must be non-empty and match what you actually tested
  (§9 — this is about portrait canvas *sizes*, not orientations).

### How these are actually enforced

Being honest about what's structural and what isn't matters more than
sounding stricter than the design is (this project's own signing and
architecture docs take the same line, e.g. `docs/design/signing.md`'s
"attests provenance, not review compliance"). Godot is one runtime with
full engine access from GDScript (ADR 0002) — there's no per-activity
sandbox stopping a script from calling `HTTPRequest` or instantiating a
`Label` if a contributor really tried to. Two things actually hold the
line:

1. **The API offers nothing else.** Every helper above is audio, touch, or
   local-storage shaped. Following the path of least resistance — using
   what the SDK gives you — produces a compliant activity by construction,
   with no rule to remember.
2. **Mechanical checks before a maintainer signs.** `TextAudit.find_text_nodes()`
   (§ used by the shell's own crash-containment test and available to your
   activity's tests) and `tools/lint_activity.sh` (a static grep over your
   `.gd`/`.tscn` files for text-capable node types and forbidden network
   classes) turn `docs/guides/activity-review.md` into commands a reviewer
   actually runs, not things they eyeball. Signing is the real gate
   (`docs/design/signing.md`): only maintainers sign, and only after this
   checklist passes — the mechanical checks are what make that a fact
   about the artifact, not a promise about the process.

## 9. Orientation: portrait, always

Every activity is designed and laid out assuming a **portrait-shaped
canvas, always** — `shell/project.godot` locks
`display/window/handheld/orientation` to `"portrait"`, so the shell (and
therefore every activity running inside it) never presents a landscape
canvas on a handheld device, regardless of how the physical device is
held or mounted. There is no orientation field in the manifest and no
per-activity orientation logic to write.

This was a deliberate tradeoff, not a default: it keeps every activity's
layout math to one shape family (matching a toddler's typical one-hand or
propped-up-device grip, and the shell's own portrait-first base resolution
— `shell/README.md`), at the cost of never presenting a true landscape or
native-4:3-tablet-shaped layout. `declared_layouts` (§3) is where the
*portrait-shaped canvas range* still varies — `phone_portrait` (tall,
narrow, ~19.5:9) through `tablet_portrait` (squarer) — and is what you're
actually testing across, same three physical devices T1.1 established,
viewed portrait.

## 10. Building, exporting, signing

```sh
godot --headless --path activities/<your_activity> --quit          # smoke: imports cleanly
godot --headless --path activities/<your_activity> --export-pack "Linux" build/<id>.pck
```

Producing the `.pck` is as far as this document goes — signing it
(`tools/sign`) and the shell actually verifying and loading a real signed
PCK is T1.4's scope (`docs/design/signing.md`), a separate, security-labeled
task, not yet built as of this writing. Until it lands, an activity is
verified by running its own GUT suite (`/activities/_template/tests` is
the worked example) against its own `activity.tscn` directly — proving the
lifecycle contract, manifest validity, and textlessness without needing
the production loading path to exist yet.

## 11. Versioning

`min_shell_version` in your manifest is compared against the shell's own
`config/version` (`shell/project.godot`, currently `0.1.0` — this is the
shell's first version, added alongside this SDK). ADR 0002 calls out that
"Godot version upgrades become ecosystem-wide events requiring a min-shell
versioning scheme in the activity manifest" — this is that scheme. It's
informational, not a security boundary: an incompatible activity isn't a
threat, just possibly broken in a way you'd want to know about before it
ships.

## 12. Known limitations, stated openly

- `TextAudit` and the review checklist catch every built-in Godot control
  that renders text, but not text drawn by a custom `_draw()` call or
  baked into an image asset. Review still requires a human actually
  looking at the activity — the mechanical checks narrow that job, they
  don't replace it.
- `Draggable` doesn't arbitrate overlapping targets catching the same
  initial touch (§6). Not exercised by `SAFE_MARGIN`-spaced layouts; a
  real constraint if that ever changes.
- The 160-unit minimum touch target and 0.5s hold threshold are design
  estimates pending T1.5's real-child validation, not measured values.
- Portrait-only (§9) is a one-way-feeling decision to revisit only with
  real weight behind it — every future activity is built against it.
