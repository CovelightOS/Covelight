# Contributing to Covelight

Covelight is volunteer-built, non-profit, forever. Every contribution helps
a child on *both* tiers at once — the shared Godot platform means one
activity, one fix, one review ships to the Android app and Covelight OS
alike. Thank you for being here.

## Your first PR, start to finish

1. Clone the repo.
2. Read [`CLAUDE.md`](CLAUDE.md). It's short, and it's the actual rulebook —
   everything below assumes you've read it. (If you're using Claude Code,
   it loads automatically; read it yourself anyway.)
3. Pick a task — see [Picking a task](#picking-a-task) below.
4. One task = one branch = one PR, named after the task ID (e.g.
   `t1.3-activity-sdk`).
5. Work the task's **Acceptance** checklist until every box is true. Update
   the task's status in its plan doc (`[ ]` → `[x]`) in the same PR.
6. Open the PR. Add the `security` and/or `honest-labeling` label if it
   applies (see [PR conventions](#pr-conventions)).

That's the whole loop. Nobody needs to unblock you for any of it — if a
task itself is ambiguous, that's a bug in the task; open an issue instead
of guessing.

## You don't need to be a game developer or a kernel hacker

Most of this project is not the two hardest-sounding pieces (Godot engine
work, kernel/bootloader work). Pick the lane that matches what you already
know:

- **Learning activities** (Godot 4 / GDScript) — the on-ramp. The activity
  SDK (`docs/design/activity-sdk.md`, landing in Phase 1) gives you a
  template, audio helpers, and an input API — a first activity is a
  weekend project, and no prior game-dev experience is assumed.
- **Android** — kiosk wrapper, Device Owner provisioning, vendor-skin quirk
  hunting. We especially need people with Xiaomi/MIUI, Samsung, and Oppo
  devices to test against.
- **Design & audio** — textless UI is its own craft: iconography, sound
  design, interaction for pre-literate users. No engineering required.
- **Rust / Linux / embedded** — the signing crate, sync daemon, protocol
  fuzzing, kernel config, device ports (OS tier).
- **Desktop / TypeScript** — the Companion (provisioning + sync client).
- **Security review** — threat modeling, protocol review, honest-labeling
  review of public copy.

Not sure which fits? Start with a learning activity — it's self-contained,
reviewed against one short checklist (`docs/guides/activity-review.md`),
and ships independently of everything else.

## Picking a task

[`docs/plan/00-overview.md`](docs/plan/00-overview.md) is the map. Phase
files (`docs/plan/01-*.md` through `04-*.md`) hold the actual tasks —
note phases 3 through 6 all live in the one skeletal file, `04-*.md`, since
they haven't been fully specced yet.

Each task carries a tag:

- **`[CC]`** — completable end-to-end without needing project-holder
  access (accounts, hardware, legal standing).
- **`[human]`** — needs the project holder specifically (namespace claims,
  purchases, physical hardware, legal).
- **`[CC+human]`** — build it, then a human verifies on real hardware or a
  real account.

And a status: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked
(the line says by what).

Grab any `[ ]` task whose dependencies (listed on the task line) are
already `[x]`. Don't start a `[!]` task until its blocker clears. If two
people might be circling the same task, say so in an issue before either
of you starts — cheaper than duplicating the work.

## PR conventions

- **One task = one branch = one PR.** If a task turns out to be more than
  one PR of work, split it in the plan doc first, in that same PR — don't
  silently grow the scope.
- **The Acceptance checklist is the definition of done.** Every box
  checked, explicitly, tests passing, before the PR is ready for review.
- **Labels:**
  - `security` — anything touching kiosk policies, content/OS signing,
    `syncd` auth, kernel config, or user separation.
  - `honest-labeling` — anything touching a user-facing safety claim
    (docs, Companion copy, website). Every claim must match the tier it
    describes (CLAUDE.md constraint #7).
  - Apply both if a PR touches both. See CLAUDE.md's Conventions section
    for the exact trigger list — this file doesn't duplicate it.
- Keep PRs small and single-purpose, same as the task they implement.

## The rules that don't bend

Full list and reasoning: [`CLAUDE.md`](CLAUDE.md) — read it, don't rely on
this summary. Four that catch newcomers most often:

- **No text, ever, in anything a child sees.** Icons, color, animation,
  and audio only — no exceptions for "just a debug label."
- **No telemetry, analytics, or tracking, anywhere, ever.** Not opt-in, not
  anonymized, not "just a crash count."
- **Tier labeling is exact.** "Air gap," "structural," "cannot network" —
  Covelight OS only, never the app. If you're writing user-facing text,
  check every safety claim against the tier it actually describes.
- **No attention-engineering in activities.** No streaks, variable
  rewards, autoplay chains, or pressure timers. Activities end calmly.

If a task seems to require breaking one of these, stop and flag it in the
PR or an issue — don't route around it quietly.

## Code of conduct

Be respectful. Assume good faith. Harassment, personal attacks, and
discriminatory language aren't welcome here, in issues, PRs, or discussions.
Maintainers may remove content or block participants who don't meet this
bar. If something happens that needs attention, open an issue or start a
discussion — a dedicated contact address will replace this once the
project's namespaces (T0.6) are claimed.

## License

Not yet decided (see `docs/decisions/0003-license-choice.md`). Don't add
license headers to any file until that lands.

## Questions

Open an issue or start a discussion — that's the only channel right now.
