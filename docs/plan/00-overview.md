# Covelight Build Plan — Overview

This folder is the step-by-step execution plan. Each phase file breaks the work into tasks sized for a single Claude Code session (roughly: one PR each).

## How to run a task with Claude Code

1. Open a Claude Code session in the repo root. `CLAUDE.md` loads automatically — it carries the inviolable constraints. Do not paraphrase constraints into prompts; point at the file.
2. Reference the task by ID: *"Implement T1.4 from docs/plan/02-phase1-shell.md."* Claude Code should read the task, its dependencies, and `ARCHITECTURE.md` sections it cites.
3. One task = one branch = one PR. If a task turns out to be two PRs of work, split the task in the plan doc first (update the doc in the same PR).
4. Every task's **Acceptance** checklist is the definition of done. The session ends with all boxes checkable, tests passing, and the plan doc's status updated.
5. Tasks touching kiosk policies, signing, `syncd` auth, kernel config, or user separation carry the `security` label; tasks touching user-facing safety claims carry `honest-labeling` (see CLAUDE.md conventions).

## Task tags

- **[CC]** — Claude Code can complete this end-to-end (code, tests, docs).
- **[human]** — Only Yusuf can do this (accounts, purchases, physical hardware, legal).
- **[CC+human]** — Claude Code builds it; a human must verify on a real device or account.

## Status convention

Each task line starts with a status: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (say by what).

## Phase map & critical path

```
Phase 0  Foundation           → repo, CI, signing design          (docs: 01)
Phase 1  Shared platform      → Godot shell, SDK, activities      (docs: 02)  ← CRITICAL PATH
Phase 2  Tier 1 kiosk         → Android wrapper, Companion setup  (docs: 03)  ← FIRST RELEASE
Phase 3  Tier 1 hardening     → device matrix, F-Droid            (docs: 04)
Phase 4  Tier 2 OS track      → syncd, protocol, pmOS image       (docs: 04)
Phase 5  Tier 2 hardware      → Pi Zero gadget, OnePlus 6         (docs: 04)
Phase 6  Device ecosystem     → database, checker, probe, Halium  (docs: 04)
```

Phases 3–6 all live in one file, `docs/plan/04-phase3-to-6-skeletons.md` — hence the repeated "docs: 04" above.

Phases 0–2 are specced task-by-task. Phases 3–6 are deliberately skeletal: they get their full task breakdown when their phase begins, so the plan reflects what we've learned instead of guesses made months earlier. **Do not pre-build Phase 4+ tasks while Phase 1–2 tasks are open** — the critical path is a child using Covelight, not architectural completeness.

## Parallel workstreams (not phase-gated)

- **Marketing / build-in-public** (LinkedIn): runs continuously; each phase's completed tasks are post material.
- **Device database curation** (`/devices`): `oem-policy.yml` and `soc.yml` research can proceed any time — it's [human]-led research with [CC] tooling support.
- **License decision** and **trademark check**: open items, block the first tagged release, nothing else.
