# /shell

The Covelight Shell — the Godot 4 application children actually see: boot →
home → activity → home, textless, fullscreen, sound-driven. Also hosts the
activity SDK (`sdk/`) that learning activities build against.

Identical on both tiers; nothing here is tier-specific.

**Tier:** shared

**Status:** T1.1 (project bootstrap + responsive scaffolding), T1.2 (shell
state machine + crash containment), and T1.3 (activity SDK contract) done.
See `docs/plan/02-phase1-shell.md` (Phase 1, critical path) for the rest.

## Renderer: GL Compatibility

Set in `project.godot` (`renderer/rendering_method` and its `.mobile`
override, both `"gl_compatibility"`). Of Godot 4's three renderers
(Forward+, Mobile, Compatibility), Compatibility is the only one that runs
on GLES3-class hardware without a discrete/modern GPU — which is the actual
hardware population this project targets: "the phone already in your
drawer" (README.md), years-old Android devices, and Tier 2's tablet
reference hardware (ARCHITECTURE §3/§4). Forward+ and Mobile both assume
GPU capability this project explicitly cannot assume. Every future activity
inherits this — it's a project-wide constraint, not a per-scene choice.

## Stretch strategy: `canvas_items` + `expand`

Three target aspect ratios have to share one layout system:

- phone portrait (~1080×2340, 19.5:9)
- phone landscape (same device, rotated)
- tablet landscape (2048×1536, 4:3 — Tier 2 reference hardware)

These are not small variations on one shape — portrait phone and 4:3 tablet
are a completely different silhouette. Two other options were available and
rejected:

- **`viewport` stretch** renders at a fixed virtual resolution into a
  texture, then scales that texture to fit the window. With `keep`-family
  aspect modes this means letterboxing (black bars) or, with `ignore`,
  distortion — full-width or full-height bars are unacceptable at these
  ratios (a 4:3 tablet under a phone-shaped base resolution would show
  enormous bars), and distortion is unacceptable for anything touch-sized.
- **`canvas_items` + `keep`/`keep_width`/`keep_height`** has the same
  letterbox problem as `viewport` — it fixes the visible canvas to the base
  aspect and bars off whatever doesn't fit.

**`canvas_items` + `expand`** scales UI elements based on the *matching*
axis (so a shape sized in project units stays a stable physical size)
and *reveals more canvas* on the axis with extra room, instead of
letterboxing it. Paired with anchors (below), this is what keeps touch
targets a consistent physical size across a 19.5:9 phone and a 4:3 tablet
without a single per-resolution special case. This is also Godot's own
documented recommendation for exactly this situation.

**Base resolution: 1080×2340** (phone portrait). The primary Tier 1 device
class is "nearly any Android phone" (README.md) — phone is the common case,
tablet the secondary one — so the base is set to the more constrained,
narrower target; both the tablet and phone-landscape cases expand from it
rather than shrinking down to it.

Every child-facing scene positions its elements with **anchors** (`Control`
node `anchor_left/top/right/bottom` + `offset_*`), not fixed pixel
coordinates, so it reflows automatically as `expand` reveals more or less
canvas. `scenes/home.tscn` is the proof: four corner shapes and one
centered shape, anchored to their respective corners/center, holding
correct margins and relative position at all three ratios (verified in
T1.1's PR). T1.3's SDK carries this same anchor discipline into the
activity contract (`docs/design/activity-sdk.md`).

**Orientation:** `window/handheld/orientation` is locked to `"portrait"` —
a T1.3 decision every activity is built against (`docs/design/
activity-sdk.md` §9): the shell, and everything it loads, only ever
presents a portrait-shaped canvas, regardless of physical device
orientation. `config/version` (currently `0.1.0`) is the shell's own
version, compared against an activity manifest's `min_shell_version`.

## Safe-margin convention

T1.1's original placeholder shapes sat 24px from the screen edge — flush
enough that a small child resting their thumb on the device's physical
edge (which they do) would trigger them by accident. Every child-facing
element now insets at least `LayoutConstants.SAFE_MARGIN` (120.0, in
project units at the 1080-wide base) from any screen edge instead —
roughly 0.3in of physical margin at typical phone pixel density, in the
ballpark of Android's own edge-gesture exclusion zone, comfortably wider
than a resting thumb pad.

`LayoutConstants` (`scripts/layout_constants.gd`) is a script constant, so
GDScript-driven layout can reference it directly. `.tscn` files are static
data and can't evaluate a GDScript constant, so hand-placed anchors/offsets
in the editor must match the value (120.0) manually — `scenes/home.tscn`'s
corner shapes are the reference example. **T1.3's SDK inherits this as a
rule**: no activity places an interactive element closer than
`SAFE_MARGIN` to any edge.

## The state machine

`scripts/shell.gd` (`scenes/shell.tscn`, the project's main scene):
**boot → home → activity-running → return-to-home → home.** Every
transition is a fade-to-black-and-back plus a soft procedurally-generated
placeholder tone (`scripts/transition_overlay.gd`) — no text, ever
(constraint #1), and no external audio asset (T1.7 replaces the tone with
the real cue library; the `cover()`/`reveal()` interface is what should
survive that swap).

**Crash containment** is the load/liveness watchdog in `shell.gd`: starting
an activity arms a timer (`load_timeout_seconds`, default 5s), and only the
activity calling `report_ready()` (see the activity contract below)
disarms it. An activity that throws during load, hangs waiting on
something that never resolves, or otherwise never gets that far never
disarms the timer either — indistinguishable to the shell from one still
loading, until the timeout fires and the shell calmly returns to home. No
error text, no dialog; the child never sees a difference between "loading
took a moment" and "that failed."

**Honest limitation:** this cannot recover from a true busy-loop hang
inside a single frame. GDScript is single-threaded, so a tight infinite
loop blocks the engine's own `Timer` callbacks too — nothing in-process can
preempt that. Recovering from it needs OS-level process supervision, which
is Tier 1/2 territory (Device Owner policy, `covelight-syncd`), not this
shell's job. Verified directly against the engine before relying on it:
a child node's script error during `_ready()` does **not** propagate as an
exception to the caller — the caller's code after `add_child()` keeps
running normally (see `scenes/activities/crashing_activity.gd`'s comment
and T1.2's PR for the probe that confirmed this).

### The activity contract

`sdk/activity_base.gd` (`class_name ActivityBase`, extends `Control`) is
the full T1.3 lifecycle contract activities extend: `report_ready()` once
loaded and able to take input, `report_finished()` when done, plus
optional `_on_activity_paused()`/`_on_activity_resumed()` hooks. The
signal pair (`activity_ready`/`activity_finished`) is unchanged from T1.2
on purpose, so T1.4's real signed-PCK loading can instantiate a real
activity scene through the exact same
`Shell.start_activity(activity_scene: PackedScene)` entry point, with no
rework to the shell itself. Full contract, manifest format, and the rest
of the SDK surface: `docs/design/activity-sdk.md`.

- `scenes/activities/stub_activity.tscn` — reports ready immediately, runs
  ~1.5s, reports finished. Proves the normal end-to-end path.
- `scenes/activities/crashing_activity.tscn` — reports ready **never**;
  crashes synchronously in `_ready()` instead. Proves crash containment
  (see tests below).

## What's here

- `project.godot` — renderer + stretch settings above, GUT enabled as an
  editor plugin.
- `scenes/shell.tscn` + `scripts/shell.gd` — the state machine, the
  project's main scene.
- `scenes/home.tscn` + `scripts/home.gd` — placeholder home screen (taps
  anywhere to start the stub activity). T1.5 replaces this with the real
  textless activity chooser.
- `scenes/transition_overlay.tscn` + `scripts/transition_overlay.gd` — the
  fade + placeholder-tone transition, explicitly replaceable by T1.7.
- `scenes/activities/` — the stub and crashing test activities above.
- `sdk/` — the T1.3 activity SDK: `activity_base.gd` (lifecycle contract),
  `activity_manifest.gd`, `audio_cue.gd`, `touch_target.gd`,
  `draggable.gd`, `activity_progress.gd`, `layout_constants.gd`
  (safe-margin + minimum touch-target constants), `text_audit.gd` (the
  shared textless-check reused by both the shell's own tests and any
  activity's). Full contract: `docs/design/activity-sdk.md`. Symlinked
  into every activity project as `addons/covelight_sdk` — see that doc's
  §2 for why.
- `addons/gut/` — vendored GUT 9.7.1 (MIT), built specifically for Godot
  4.7.x. `tests/` holds the actual test scripts. Also symlinked into every
  activity project as `addons/gut`, so an activity can run its own GUT
  suite the same way the shell does.
- `export_presets.cfg` — the `Linux` export preset CI exports against.
  Deliberately tracked, not gitignored (a generic Godot `.gitignore`
  template excludes this file by default; it's overridden at the repo
  root specifically so `godot-export` in CI has something to export).

## Running it locally

Requires the Godot 4.7 editor (`brew install --cask godot` on macOS, or
the equivalent from godotengine.org).

```sh
godot --headless --path shell --quit   # smoke test: opens/imports cleanly
godot --path shell                      # actually see it, real window
godot --path shell --resolution 2048x1536   # eyeball a different ratio
```

Note on verifying stretch behavior locally: headless mode has no real
window (`DisplayServer.window_get_size()` reports `(0, 0)`), so
`canvas_items`/`expand` has nothing real to expand against — don't trust
a headless screenshot for layout verification, only for "does it import
without erroring." Judge the actual reflow with a real window.

### Running the tests

```sh
godot --headless --path shell --import   # first run only (see note below)
godot --headless --path shell -s addons/gut/gut_cmdln.gd -gexit
```

The `--import` step matters on a fresh checkout: `class_name`-declared
global classes (`Shell`, `ActivityBase`, GUT's own classes, ...) are only
registered by an editor-mode project scan, not by a plain headless run —
skip it and GUT fails fast with its own message telling you to run exactly
this. Undocumented Godot behavior, found by testing, not assumed.

Also worth knowing: if a test script fails to *parse* (not just fails an
assertion), GUT prints "Nothing was run" but still exits `0` — a plain
exit-code check in CI would go green having run zero tests. `godot-test`
in CI greps the output for `"All tests passed!"` specifically, so a parse
regression fails the build instead of silently passing.

## CI

- `godot-export` downloads the pinned Godot 4.7 Linux editor + export
  templates (cached across runs — the templates package alone is ~1.2 GB,
  cache-miss cost is real and expected on the first run after a version
  bump), then runs a real `--export-debug "Linux"`. Fails the build if the
  project doesn't export.
- `godot-test` (separate cache — it only needs the editor, not the export
  templates) runs the GUT suite headless, with the parse-failure guard
  above.
