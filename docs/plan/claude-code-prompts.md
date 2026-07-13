Implement <TASK ID> from docs/plan/<file>.

Read first:

- docs/plan/<file> — the task, its dependencies, its acceptance criteria
- CLAUDE.md — inviolable constraints (already auto-loaded; obey without exception)
- <any doc the task cites>

Do not start coding until you have read those and stated back:

1. What you're building, in two sentences
2. Which CLAUDE.md constraints apply to this task specifically
3. Anything in the task that is ambiguous — ask me, don't guess

Then implement. Scope: this task only. If you discover work that belongs to
a different task, note it and stop — do not expand scope.

Finish by:

- Verifying every Acceptance checkbox in the task, explicitly, one by one
- Updating the task status in the plan doc ([ ] → [x])
- Committing on a branch named <task-id>-<short-slug>
