# Repo Harness workflow concepts on installed `0.12.0`

Shared rules: [`Repo Harness safety`](../safety.md).

The public website describes the desired model:

```text
PRD -> Sprint -> Goal -> execution -> Human Review Card -> check -> ship
```

Durable truth lives in repository files:

```text
plans/prds/
plans/sprints/
plans/
tasks/contracts/
tasks/reviews/
tasks/todos.md
.ai/harness/checks/latest.json
```

## Website versus installed fork

The website currently shows newer top-level commands:

```text
repo-harness adopt
repo-harness prd
repo-harness sprint
repo-harness goal
repo-harness check
repo-harness ship
```

Your installed fork `0.12.0` at the tested branch does not expose those commands.
Do not copy website commands blindly. Verify with:

```bash
repo-harness --help
repo-harness run --help
```

## Verified installed equivalents

| Website concept | Installed `0.12.0` path |
|---|---|
| Adopt repository | `repo-harness init [--mode minimal|standard|self-host]` |
| Resolve task risk/profile | `repo-harness state resolve --json` |
| Create/maintain workflow artifact | bundled helpers via `repo-harness run <helper>` or reviewed manual Markdown |
| Workflow consistency check | `repo-harness run check-task-workflow --strict` |
| Prepare Codex handoff/goal | `repo-harness mcp prepare-goal` or bundled handoff helpers |
| Cross-provider review | `repo-harness cross-review` |
| Ship/PR | use installed helper only if present; otherwise normal reviewed Git/GitHub workflow |

List packaged helpers before using one:

```bash
repo-harness run --help
```

## Lite, Standard, Strict

These are task-risk workflows, not installation modes:

- **Lite** — bounded brief, edit, targeted test;
- **Standard** — plan, edit, verify, one review;
- **Strict** — contract, isolated worktree, checks, external acceptance.

Resolve effective state for a concrete operation:

```bash
repo-harness state resolve \
  --target-path path/to/file \
  --operation modify \
  --json
```

Do not create heavyweight PRD/Sprint/contract artifacts merely for ceremony when
the effective profile is Lite.

## Hooks

Website hook concepts remain valid: hooks accelerate and guard the workflow but
do not replace plans, contracts, review cards, or checks.

On this Nix host, do not run the public website installer to write
`~/.claude/settings.json` or `~/.codex/hooks.json`. Inspect upstream projections
safely with:

```bash
repo-harness-generate-host-config
```

Port only reviewed settings into `nix-config`.

## Human Review Card

For a completed task, record:

- verdict;
- intended versus actual changed paths;
- commands/tests that passed;
- residual risk;
- rollback.

Keep commit, push, PR creation, readiness, and merge as separate human-approved
boundaries.
