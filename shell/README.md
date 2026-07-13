# /shell

The Covelight Shell — the Godot 4 application children actually see: boot →
home → activity → home, textless, fullscreen, sound-driven. Also hosts the
activity SDK (`sdk/`) that learning activities build against, landing in
T1.3.

Identical on both tiers; nothing here is tier-specific.

**Tier:** shared

**Status:** T1.1 (project bootstrap + responsive scaffolding) done. See
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
canvas. `scenes/main.tscn` is the proof: four corner shapes and one
centered shape, anchored to their respective corners/center, holding
correct margins and relative position at all three ratios (verified below).
T1.3's SDK will carry this same anchor discipline into the activity
contract.

## What's here

- `project.godot` — renderer + stretch settings above.
- `scenes/main.tscn` — placeholder scene proving the scaffolding: five
  `ColorRect` shapes (four corners + center), zero text (constraint #1 —
  a `ColorRect` has no text property to misuse, which is the point even in
  throwaway scenes). Gets replaced once T1.2's shell state machine exists.
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

## CI

`godot-export` in `.github/workflows/build.yml` downloads the pinned Godot
4.7 Linux editor + export templates (cached across runs — the templates
package alone is ~1.2 GB, cache-miss cost is real and expected on the first
run after a version bump), then runs a real `--export-debug "Linux"`. It
fails the build if the project doesn't export.
