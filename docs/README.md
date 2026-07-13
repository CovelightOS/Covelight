# Covelight Documentation

Map of everything in `/docs`. Repo-root docs (`README.md`, `ARCHITECTURE.md`, `CLAUDE.md`, `CONTRIBUTING.md`) are the entry points; this folder is the depth.

> **`CLAUDE.md` lives at the repo ROOT and must stay there.** Claude Code auto-loads it from the root at session start. Moving it into `/docs` would silently disable constraint loading for every future session.

**Status tags:** ✅ authoritative · 🟡 stub — outline only, filled by the named plan task · 🔓 open decision

## plan/ — the execution plan

| File                                                                                                                 | Status                  |
| -------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| [00-overview.md](plan/00-overview.md) — how to run tasks with Claude Code, tags, critical path                       | ✅                      |
| [claude-code-prompts.md](plan/claude-code-prompts.md) — copy-paste session prompts                                   | ✅                      |
| [01-phase0-foundation.md](plan/01-phase0-foundation.md) — repo, CI, signing design, namespaces                       | ✅                      |
| [02-phase1-shell.md](plan/02-phase1-shell.md) — Godot shell, SDK, first activities _(critical path)_                 | ✅                      |
| [03-phase2-kiosk.md](plan/03-phase2-kiosk.md) — Android kiosk + Companion _(first release)_                          | ✅                      |
| [04-phase3-to-6-skeletons.md](plan/04-phase3-to-6-skeletons.md) — **phases 3, 4, 5 and 6 all live in this one file** | ✅ (skeletal by design) |

## decisions/ — Architecture Decision Records

| ADR                                                                                                | Status  |
| -------------------------------------------------------------------------------------------------- | ------- |
| [0001 — Two-tier model](decisions/0001-two-tier-model.md)                                          | ✅      |
| [0002 — Single Godot runtime for all child-facing content](decisions/0002-single-godot-runtime.md) | ✅      |
| [0003 — License choice](decisions/0003-license-choice.md)                                          | 🔓 T0.8 |
| [0004 — "Covelight" trademark clearance](decisions/0004-covelight-name-trademark.md)               | 🔓 T0.7 |

See [decisions/README.md](decisions/README.md) for the ADR format. An ADR is written when a decision is _made_, including reversals — 0001 exists because we reversed one.

## design/ — engineering specifications

| File                                                                                 | Status       |
| ------------------------------------------------------------------------------------ | ------------ |
| [signing.md](design/signing.md) — Ed25519 content signing                            | ✅ (pending security review before T1.4) |
| [activity-sdk.md](design/activity-sdk.md) — the activity contract                    | 🟡 T1.3      |
| [kiosk-provisioning.md](design/kiosk-provisioning.md) — Device Owner design (Tier 1) | 🟡 T2.2/T2.4 |
| [protocol.md](design/protocol.md) — USB sync protocol (Tier 2)                       | 🟡 Phase 4   |

## guides/ — how-tos for humans

| File                                                    | Audience     | Status       |
| ------------------------------------------------------- | ------------ | ------------ |
| [tier1-setup.md](guides/tier1-setup.md)                 | Parents      | 🟡 T2.7      |
| [building-activities.md](guides/building-activities.md) | Contributors | 🟡 T1.3/T1.8 |
| [activity-review.md](guides/activity-review.md)         | Reviewers    | 🟡 T1.3      |
| [porting-devices.md](guides/porting-devices.md)         | Porters      | 🟡 Phase 6   |

## devices/ — hardware support _(cross-tier)_

| File                                                                                                | Tier   | Status     |
| --------------------------------------------------------------------------------------------------- | ------ | ---------- |
| [device-database.md](devices/device-database.md) — DB design, six-requirement scoring, tiers, probe | Tier 2 | ✅         |
| [device-matrix.md](devices/device-matrix.md) — vendor-skin test matrix                              | Tier 1 | 🟡 Phase 3 |

## research/ — external research findings

Distilled, dated, committed notes from external research (NotebookLM etc). See [research/README.md](research/README.md) for the format and the rule: findings never silently edit the plan — they land as notes, then a PR against the plan cites them.

## Rules for this folder

1. **Stubs are contracts, not placeholders.** A 🟡 stub states what the doc will cover and which task owns it; the owning task's acceptance includes replacing the stub. Don't write content into a stub outside its task.
2. **Link, don't duplicate.** ARCHITECTURE.md owns the design narrative; docs here go deeper on one topic and link back. If the same fact lives in two files, one of them is wrong already or will be soon.
3. **Honest labeling applies here too** (CLAUDE.md #7): any doc making safety claims distinguishes policy-based (Tier 1) from structural (Tier 2/OS) protection, every time.
