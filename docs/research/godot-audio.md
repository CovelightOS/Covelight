# Godot audio bus research — for T1.7 (Audio system)

**Status:** NotebookLM-queried (the "Covelight" notebook, 61 sources) per
instruction. The notebook's own sources only cover this topic as a Godot
class-reference table of contents (bus/effect/class names, no method
bodies) plus this repo's own plan doc — so the answer below is NotebookLM
surfacing general Godot 4 engine knowledge, not new information extracted
from a source. Cross-checked against stable, version-independent Godot 4
API and used as-is; flagged here rather than presented as source-verified.

## Findings that shape the design

1. **Buses are a flat array on `AudioServer`, created and routed at
   runtime.** `AudioServer.add_bus(at_position := -1)` appends a bus (no
   `.tres` asset required); `AudioServer.set_bus_name(idx, name)` names it;
   every bus sends to another bus by name via
   `AudioServer.set_bus_send(idx, target_name)`, eventually reaching
   `"Master"`. A new bus's default send target is already `"Master"`, so a
   bus created for this task and never re-sent still reaches the speaker —
   confirmed as engine-default behavior, not something this doc invents.
   **Consequence:** shell startup can build its bus layout (`Chrome`,
   `Content`, both -> `Master`) in code, idempotently, rather than shipping
   a separate bus-layout resource file to keep in sync.

2. **Volume is stored in dB; linear is a UI-facing convenience only.**
   `AudioServer.set_bus_volume_db(idx, db)` is the actual write path (`0.0`
   dB = unity gain, roughly `-80.0` dB reads as silence). Godot 4.3+ also
   exposes `set_bus_volume_linear(idx, linear)` / `get_bus_volume_linear`
   which do the `linear_to_db`/`db_to_linear` conversion internally and
   handle the `0.0` edge (true silence, not `-inf` dB) correctly —
   preferred here over hand-rolling `linear_to_db()` for the persisted
   master-volume value, since `linear_to_db(0.0)` is `-inf` and would need
   its own clamp anyway. `AudioServer.set_bus_mute(idx, bool)` exists
   separately from volume and is not used by this task (mute is a future
   parent-menu concern, not this one).

3. **`AudioStreamPlayer.bus` is a plain `StringName` property.** Setting it
   routes that player's output into the named bus; it fails silently to
   `"Master"`-equivalent behavior if the name doesn't exist (defensive
   fallback, not relied upon here — this task always creates its buses
   before anything plays). This is already how `ActivityAudio` routes
   audio (`shell/sdk/audio_cue.gd`); T1.7 changes only which bus name it
   uses, not the mechanism.

4. **Ducking has an engine-native path (`AudioEffectCompressor` sidechain)
   that this task deliberately does not use.** The compressor's sidechain
   input reacts to the *other* bus's signal level above a threshold —
   correct for music-vs-voice style ducking in a game with continuous
   soundtracks, but threshold/attack/release tuning makes the exact
   ducking moment level-dependent and harder to assert in a GUT test
   ("did it duck" becomes "did the signal exceed threshold long enough").
   This project's cues are short, discrete, and few (a handful of
   transition/UI tones, not a continuous score), so a **direct, deterministic
   bus-volume tween** (`AudioServer.set_bus_volume_linear` animated by a
   `Tween` over a known duration, then restored) is used instead: cheaper
   to reason about, cheaper to test, and calm by construction (a fixed,
   gentle fade, never a sudden level jump). Noted as a considered
   alternative, not a gap — revisit only if a future need (e.g. a
   continuous ambient bed) actually wants level-reactive ducking.

5. **Master-volume persistence is a `ConfigFile` + autoload pattern**,
   consistent with `shell/sdk/activity_progress.gd`'s existing
   `user://`-based persistence (T1.3): an autoload reads a small
   `ConfigFile` under `user://` at startup, applies the stored linear
   volume to the `Master` bus, and re-writes the file whenever the value
   changes. Same shape as this project's progress storage, so no new
   persistence pattern is introduced for this task alone.

## What this doc does *not* cover

Bus effects beyond the compressor (EQ, limiter, reverb) — out of scope;
T1.7 needs routing, ducking, and volume persistence only. Godot's `Music`
vs `SFX` bus-splitting conventions from tutorials aren't used verbatim
either — this project's split is `Chrome` (shell transition/UI cues) vs
`Content` (activity + home-tile audio), named for what actually duckes
what here, not for a generic game-audio taxonomy.
