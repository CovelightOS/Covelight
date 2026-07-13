# ADR 0002 — Single Godot Runtime for All Child-Facing Content

**Status:** Accepted · 2026 (predates ADR 0001; restated here because the two-tier model strengthened rather than weakened it)

## Context

The child-facing environment is textless — pure animation, touch, and audio, for users who cannot read. Two questions recurred during design: *why a game engine for a non-game*, and *why can't contributors build activities in whatever framework they prefer* (Flutter, web views, native toolkits, other engines)?

An earlier Qt/QML/C++ design was already superseded on content-velocity grounds: a "tap the animal, hear the sound" activity is hours of work in an engine and weeks in a conventional UI toolkit, and the project lives or dies on activity contribution volume.

## Decision

All on-device, child-facing content runs in **exactly one runtime: Godot 4**, shipped as Ed25519-signed PCK bundles loaded dynamically by the Covelight shell. No web views, no alternative engines, no interpreters, no content plugin systems — on either tier. (CLAUDE.md constraint #2; signature rule is constraint #3.)

Contributors are not required to be game developers: the activity SDK (`docs/design/activity-sdk.md`) — scene template, audio helpers, input API — is a first-class deliverable precisely so a first activity is a weekend-sized task.

## Consequences

**Positive.** One runtime means one sandbox to reason about, one signing/loading pipeline, one attack surface, and one skill set for the entire content ecosystem. The textless, audio-driven, animation-heavy workload is engine-native. Content is portable across tiers by construction — the same PCK runs on the Android app and on Covelight OS.

**Negative / accepted.** Contributors with existing Flutter/web skills face a (deliberately small) learning step. Godot version upgrades become ecosystem-wide events requiring a min-shell versioning scheme in the activity manifest. Anything Godot genuinely cannot do well is simply out of scope for content — accepted, because the alternative (multiple runtimes on a locked-down, resource-constrained child device) multiplies the sandboxing, signing, and audit burden in exactly the place the project can least afford it.

This is the same philosophy as the Tier 2 kernel air gap applied to software: the guarantee is structural ("only signed Godot bundles load") rather than policy ("please don't ship other runtimes").
