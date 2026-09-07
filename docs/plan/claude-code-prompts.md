Implement T0.1 from docs/plan/01-phase0-foundation.md — the repo skeleton.

Read first: docs/plan/01-phase0-foundation.md, CLAUDE.md (the Repository
layout section), docs/README.md.

Create the directory structure exactly as CLAUDE.md specifies:
/shell /activities /app /companion /os /syncd /devices /docs /tools

Each directory gets a README.md stating:

- what lives there
- which tier it serves (shared / tier1 / tier2 / meta)
- its current status (most are "not started — see docs/plan/")

The docs/ folder and its contents already exist — verify its internal links
resolve and that CLAUDE.md's layout section matches reality. If they diverge,
fix CLAUDE.md in this same PR and say so.

Add a root .gitignore appropriate for Godot 4 + Rust + Android + Tauri.

Do NOT add license headers to anything — the license is undecided
(ADR 0003, task T0.8). Do NOT scaffold any code yet.

Acceptance is the checklist in T0.1. Verify each explicitly, update the
task status, commit on branch t0.1-repo-skeleton.
