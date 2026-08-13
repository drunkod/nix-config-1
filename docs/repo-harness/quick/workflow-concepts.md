# Repo Harness workflow concepts on installed `0.15.0`

Shared rules: [`Repo Harness safety`](../safety.md).

The public workflow model is:

```text
PRD -> Sprint -> Goal -> execution -> Human Review Card -> check -> ship
```

Durable truth remains in repository artifacts such as plans, contracts, reviews,
checks, and handoffs. Commands coordinate those artifacts; they do not replace
them.

## Verify the installed surface

This setup currently uses Repo Harness `0.15.0` from the moving upstream `mvp`
branch. A package version does not prove an exact source commit.

```bash
repo-harness --version
repo-harness --help
repo-harness run --help
repo-harness docs list
repo-harness docs show harness-overview
```

The website-style top-level commands below are still absent from `0.15.0`:

```text
repo-harness adopt
repo-harness prd
repo-harness sprint
repo-harness goal
repo-harness check
repo-harness ship
```

Use the installed equivalents instead.

## Installed equivalents

| Workflow concept | Installed `0.15.0` command or artifact |
|---|---|
| Adopt repository | `repo-harness init --mode minimal|standard|self-host` |
| Inspect effective task profile | `repo-harness state resolve --target-path <path> --operation <operation> --json` |
| Get one continuation unit | `repo-harness state next --json` |
| Record continuation liveness | `repo-harness state attempt ...` |
| Build capability-scoped context | `repo-harness capability-context ...` |
| Create or maintain artifacts | reviewed Markdown or `repo-harness run <helper>` |
| Check workflow consistency | `repo-harness run check-task-workflow -- --strict` |
| Prepare a handoff | `repo-harness run prepare-handoff` or `prepare-codex-handoff` |
| Resume a Codex handoff | `repo-harness run codex-handoff-resume -- --cwd "$PWD" --print-prompt` |
| Cross-provider review | `repo-harness cross-review` |
| Architecture projection | `repo-harness architecture-projection ...` |
| Crash-durable worktree shipping | `repo-harness run ship-worktrees` |
| Host readiness | `repo-harness setup check --json`, `update --check --json`, `doctor --json` |

List helper names before relying on one:

```bash
repo-harness run --help
```

## Lite, Standard, and Strict

These are task-risk workflows, not repository adoption modes:

- **Lite** — bounded brief, edit, targeted test;
- **Standard** — plan, edit, verify, one review;
- **Strict** — contract, isolated worktree, checks, external acceptance.

Resolve the effective profile for a concrete operation:

```bash
repo-harness state resolve \
  --target-path path/to/file \
  --operation modify \
  --json
```

Do not create heavyweight artifacts merely for ceremony when the effective
profile is Lite.

## Long-running continuation

Ask Repo Harness for the next bounded unit:

```bash
repo-harness state next --json
```

Treat the returned continuation envelope as read-only workflow state. It
authorizes one bounded unit, not an entire backlog. After an attempt, record its
outcome using the exact arguments shown by `repo-harness state attempt --help`.
Attempt receipts prove liveness; they do not become workflow authority.

Two completed attempts with an unchanged progress token halt with
`halt:no_progress`. Use `--outcome resumed` only as an explicit operator decision
after reviewing why progress did not advance.

## Architecture projection

Repositories adopted with the architecture-policy surface can inspect and plan
projection work:

```bash
repo-harness architecture-projection status --json
repo-harness architecture-projection plan \
  --changed-path path/to/changed-file \
  --json
repo-harness architecture-projection check \
  --changed-path path/to/changed-file \
  --json
repo-harness architecture-projection drain --json
```

If `.ai/harness/policy.json` is absent, architecture projection is not configured
for that repository. Do not present that as a CLI installation failure.

In `0.15.0`, the architecture changed-set cursor is the mutation authority.
Normal drain, stop, and manual drain operate on the same frozen changed set.
Failed or unavailable work remains pending for retry; do not manually acknowledge
failed projection work as clean.

## Setup and dependency checks

```bash
repo-harness setup check --json
repo-harness update --check --json
repo-harness doctor --json
repo-harness tools ensure codegraph --check --repo . --json
```

These read-only checks may exit nonzero when structured results contain blocked,
warning, or failing host checks. Inspect the JSON instead of assuming nonzero
means malformed output. On this host, Nix owns CodeGraph; do not execute an
imperative install or upgrade suggestion.

## Hooks and review boundaries

Hooks accelerate and guard the workflow but do not replace plans, contracts,
review cards, or checks. On this Nix host, inspect generated host configuration
with `repo-harness-generate-host-config` and port only reviewed settings into the
Nix configuration.

For completed work, record the verdict, intended versus actual paths, validation,
residual risk, and rollback. Commit, push, PR creation, readiness, and merge
remain separate decisions.
