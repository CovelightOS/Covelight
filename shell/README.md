# /shell

The Covelight Shell — the Godot 4 application children actually see: boot →
home → activity → home, textless, fullscreen, sound-driven. Also hosts the
activity SDK (`sdk/`) that learning activities build against.

Identical on both tiers; nothing here is tier-specific.

**Tier:** shared

**Status:** T1.1 (bootstrap + responsive scaffolding), T1.2 (state machine
+ crash containment), T1.3 (activity SDK contract), T1.4 (signed PCK
verification), T1.7 (central audio bus), and T1.8 (developer harness) done.
T1.5 (home screen) and T1.6 (first three signed activities, loaded live via
the full verify-then-load pipeline) are engineering-complete and awaiting
the human half of their `[CC+human]` acceptance (a real small child). The
three activities live in `/activities/{animal_sounds,shape_sorter,color_mixing}`;
their signed `.pck`+`.sig` are committed under `content/`. See
`docs/plan/02-phase1-shell.md` (Phase 1, critical path) for the rest.

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
- `scenes/home.tscn` + `scripts/home.gd` — T1.5's real textless activity
  chooser: one `HomeTile` per entry in `home.gd`'s `ACTIVITIES` list
  (currently just the T1.2 stub — there's no real installed-content
  discovery yet, that's T1.6+), laid out in a grid inset by
  `LayoutConstants.SAFE_MARGIN`, sorted by id (never by recency —
  CLAUDE.md #4). `scenes/home_tile.tscn` + `scripts/home_tile.gd` — a
  single tile: tap launches, tap-and-hold previews with a soft pulse
  (`TouchTarget`'s `tapped`/`held`/`released`, reused as-is from the SDK).
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
- `rust/pck_verify/` — the T1.4 GDExtension (`docs/design/signing.md`):
  verifies a `.pck`'s Ed25519 signature, via `covelight-crypto`
  (`/tools/covelight-crypto`), before `scripts/pck_loader.gd` ever calls
  `ProjectSettings.load_resource_pack()`. `rust/build_gdextension.sh`
  builds it and copies the platform binary into
  `addons/covelight_pck_verify/bin/` (gitignored — a compiled artifact,
  not source), which `addons/covelight_pck_verify/covelight_pck_verify.gdextension`
  points at. See "Running it locally" below — building this is a hard
  prerequisite, not optional.
- `scripts/pck_loader.gd` — verify-then-load gate (`class_name PckLoader`);
  `scripts/shell.gd`'s `start_activity_from_pck()` is the entry point that
  uses it.
- `content/` — T1.6's signed activity bundles: `<id>.pck` + `<id>.pck.sig`
  per activity, built from `/activities/*` and signed locally with the
  project key (`docs/design/signing.md`). Committed (signing is local, CI
  only verifies); the home screen loads them by path through `PckLoader`.
- `export_presets.cfg` — the `Linux` export preset CI exports against.
  Deliberately tracked, not gitignored (a generic Godot `.gitignore`
  template excludes this file by default; it's overridden at the repo
  root specifically so `godot-export` in CI has something to export).

## Running it locally

**Prerequisites, once:** the Godot 4.7 editor (`brew install --cask godot`
on macOS, or the equivalent from godotengine.org), a Rust toolchain
(rustup.rs — for the T1.4 GDExtension below), and `just`
(`brew install just` or github.com/casey/just). These three are the actual
floor — same as any Godot+Rust project, not specific friction this repo
adds.

### The fast path (T1.8)

```sh
git clone <this-repo-url> && cd covelight
just run
```

Two commands, one real window, phone-portrait by default. `just run`
chains everything that has to happen on a genuinely fresh clone — building
the GDExtension, running Godot's one-time `--import` class-registration
pass, then launching — so there's no separate "first-time setup" step to
remember. Run it again any time; each piece is cheap to re-run when
nothing changed (cargo is incremental, `--import` is idempotent).

Everything else the harness does (recipes in the repo-root `justfile`,
not here in `/shell`):

```sh
just run tablet             # or: phone-landscape -- the three ratios below
just test-shell              # this project's own GUT suite only
just test-activity animal_sounds   # one activity's own GUT suite
just test                    # everything: shell + every first-party activity
```

`just run <form>` simulates the three ratios "Stretch strategy" (above)
is built and verified against — `phone-portrait` (default, 1080×2340),
`phone-landscape` (2340×1080), `tablet` (2048×1536, 4:3). Unknown values
fail loudly (`error: unknown form factor '...'`) rather than silently
falling back to something else.

**Honest note on how this was tested:** the ≤3-command target was verified
by exporting a clean `git archive` of this repo (no `.godot/` cache, no
`target/`, no compiled GDExtension binary — a truer fresh-clone simulation
than reusing this machine's already-built copy) and running `just run`
against it end-to-end. A from-scratch container run (Ubuntu + freshly
installed Godot/Rust/just, no host caches at all) was the original plan,
but this development machine hit real host disk exhaustion partway
through that attempt — unrelated to the harness itself, and left alone
rather than "fixed" by an agent poking at unrelated system storage. The
command sequence and recipe logic were confirmed correct up to that point
(including on this machine, repeatedly, with a warm toolchain); a
container-clean run is worth re-doing once there's disk headroom, but
isn't blocking this task.

### Without `just`

Everything above is a thin wrapper; the underlying commands (also what CI
runs) work directly:

```sh
shell/rust/build_gdextension.sh              # debug build; not optional, see below
godot --headless --path shell --import       # one-time class_name registration
godot --path shell                            # real window, phone-portrait
godot --path shell --resolution 2048x1536     # eyeball a different ratio
godot --headless --path shell -s addons/gut/gut_cmdln.gd -gexit   # run tests
```

**Building the GDExtension first is not optional.** `shell/rust/pck_verify`
(T1.4, `docs/design/signing.md`) is a hard prerequisite for running *any*
part of `/shell` headless or in the editor, not a nice-to-have:
`scripts/pck_loader.gd` references the `PckVerifier` class it defines by
name at parse time, so a missing binary breaks the whole project's script
compilation, not just PCK loading — verified directly against the real
engine, not assumed (see `docs/research/godot-pck-gdextension.md`).

Note on verifying stretch behavior locally: headless mode has no real
window (`DisplayServer.window_get_size()` reports `(0, 0)`), so
`canvas_items`/`expand` has nothing real to expand against — don't trust
a headless screenshot for layout verification, only for "does it import
without erroring." Judge the actual reflow with a real window (`just run`
or `godot --path shell`, above).

The `--import` step matters on a fresh checkout: `class_name`-declared
global classes (`Shell`, `ActivityBase`, GUT's own classes, ...) are only
registered by an editor-mode project scan, not by a plain headless run —
skip it and GUT fails fast with its own message telling you to run exactly
this. Undocumented Godot behavior, found by testing, not assumed.

Also worth knowing: if a test script fails to *parse* (not just fails an
assertion), GUT prints "Nothing was run" but still exits `0` — a plain
exit-code check in CI would go green having run zero tests. `godot-test`
in CI, and `just test`/`just test-shell`/`just test-activity` above, all
grep the output for `"All tests passed!"` specifically, so a parse
regression fails the build instead of silently passing.

## CI

- `build-gdextension` compiles `shell/rust/pck_verify` and `tools/sign`
  once (release profile) and uploads both as a shared artifact — every
  other shell-touching job downloads it rather than recompiling, and
  needs it to exist before running *any* Godot command against `/shell`,
  same requirement as the local-dev note above.
- `godot-export` (`needs: build-gdextension`) downloads the pinned Godot
  4.7 Linux editor + export templates (cached across runs — the templates
  package alone is ~1.2 GB, cache-miss cost is real and expected on the
  first run after a version bump), then runs a real `--export-debug "Linux"`.
  Fails the build if the project doesn't export.
- `godot-test` (`needs: build-gdextension`; separate cache — it only needs
  the editor, not the export templates) runs the GUT suite headless
  (T1.2's shell-state-machine tests and T1.4's PCK-verification tests
  together — same `tests/` directory, same run), with the parse-failure
  guard above.
- `rust-test-gdextension` runs `cargo test`/`fmt --check`/`clippy -D warnings`
  against `shell/rust/pck_verify` directly — separate from `rust-test`
  (which only covers the `/tools` workspace) since this crate lives
  outside it, but the same conventions apply (CLAUDE.md).
- `android-build` (T2.1, `docs/plan/03-phase2-kiosk.md`) is a separate,
  independent job — see `/app/README.md`. It doesn't depend on
  `build-gdextension`'s artifact (that's a Linux `.so`, useless on Android);
  it cross-compiles its own Android binaries instead.

## Android (T2.1)

`/app` embeds the shell as a Godot Android *library* dependency
(`org.godotengine:godot`, Maven Central) rather than through Godot's own
self-contained Android export — see `/app/README.md` for why and the full
build. What lives here:

- `rust/build_gdextension_android.sh` — cross-compiles T1.4's GDExtension
  for `arm64-v8a` and `armeabi-v7a` (the two ABIs real phones from roughly
  the last decade actually ship — see ARCHITECTURE.md's "phone already in
  the drawer" target; `x86`/`x86_64` are emulator-only and skipped) into
  `addons/covelight_pck_verify/bin/android/<abi>/`. Same hard-prerequisite
  reasoning as `build_gdextension.sh` above, just for a different OS.
  Needs an installed Android NDK (`ANDROID_NDK_HOME`, or the default under
  `~/Library/Android/sdk/ndk` on macOS).
- `export_presets.cfg`'s `"Android"` preset — used only with
  `--export-pack` (packs `/shell`'s resources into `shell.pck`; produces no
  APK/AAB itself, so it needs no Godot export templates — verified
  directly: `--export-pack` never touches `custom_template/debug` or
  `custom_template/release`). `/app` bundles the resulting `shell.pck` as a
  plain asset and loads it via `GodotHost#getCommandLine()`'s `--main-pack`
  argument, per
  [Godot's Android library docs](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_library.html).
- `addons/covelight_pck_verify/covelight_pck_verify.gdextension`'s
  `android.debug.arm64` / `android.release.arm64` / `android.debug.arm32` /
  `android.release.arm32` entries — `arm64`/`arm32` are Godot's own
  architecture feature tags (`Engine::get_architecture_name()`), **not**
  Android ABI names; verified against the engine's actual feature-tag
  matcher (`core/extension/gdextension_library_loader.cpp`) rather than
  copied from an example, since a wrong tag here fails silently (the
  GDExtension just doesn't load) rather than with a clear error.
  `--export-pack` does **not** embed these `.so` files into `shell.pck`
  (confirmed by testing — only the `.gdextension` file itself gets
  packed); `/app` places them directly in its own `jniLibs/<abi>/` via
  standard Gradle native-library packaging instead, and Godot's Android
  runtime resolves the GDExtension by library basename through the normal
  Android dynamic-linker search path
  (`platform/android/os_android.cpp`'s `open_dynamic_library` falls back to
  exactly this when the declared `res://` path isn't an actual packed
  resource) — the same mechanism Godot's own official Android export uses
  for GDExtensions, just reached by placing the `.so` ourselves instead of
  letting Godot's own exporter do it.
