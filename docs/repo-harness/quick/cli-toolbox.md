# Repo Harness 0.15 CLI toolbox

Use this page to discover the installed command surface without copying examples
from a different release. Shared rules: [`Repo Harness safety`](../safety.md).

## Discover current authority

```bash
repo-harness --version
repo-harness --help
repo-harness docs list
repo-harness docs show harness-overview
repo-harness status --json
```

Read-only readiness checks may exit nonzero when their JSON contains blocked or
failing checks:

```bash
repo-harness setup check --json
repo-harness init-hook --json
repo-harness update --check --json
repo-harness doctor --json
repo-harness security scan --json
```

## Host runtime lifecycle

This Nix configuration normally uses `repo-harness-bootstrap`; do not replace it
with an upstream host mutation casually. The native 0.15 lifecycle remains useful
for inspection and migration planning:

```bash
repo-harness install --state --json
repo-harness install --dry-run --target both --profile full --json
repo-harness migrate --json
```

Mutating boundaries require separate approval:

```text
repo-harness install ...
repo-harness update ...
repo-harness uninstall ...
repo-harness migrate --apply
repo-harness install --rollback
```

Repository adoption has its own transaction rollback:

```bash
repo-harness init rollback \
  --repo /absolute/path/to/repository \
  --transaction /absolute/path/to/adoption-transaction.json
```

## Workflow state and helpers

```bash
repo-harness state resolve \
  --target-path path/to/file \
  --operation modify \
  --json
repo-harness state next --json
repo-harness run --help
```

Forward helper-specific arguments after `--`:

```bash
repo-harness run check-task-workflow -- --strict
repo-harness run codex-handoff-resume -- --cwd "$PWD" --print-prompt
```

Use `repo-harness state attempt ...` to record continuation liveness after one
bounded unit. Use `repo-harness run ship-worktrees` only as an explicitly approved
commit/push/draft-PR action.

## Context and knowledge

```bash
repo-harness capability-context status --repo "$PWD" --json
repo-harness brain status --repo "$PWD" --json
repo-harness brain check --repo "$PWD" --json
repo-harness tools ensure codegraph --check --repo "$PWD" --json
```

Capability sync and brain sync are previewable writes:

```bash
repo-harness capability-context sync \
  --repo "$PWD" --pending --dry-run --json
repo-harness brain sync --repo "$PWD" --dry-run --json
```

## Architecture projection

For repositories containing `.ai/harness/policy.json` and configured ArchContext
state:

```bash
repo-harness architecture-projection status --json
repo-harness architecture-projection plan \
  --changed-path path/to/file --json
repo-harness architecture-projection check \
  --changed-path path/to/file --json
```

`apply`, `adopt`, `drain`, and `retry-dead-letter` cross mutation or queue-state
boundaries. Preview/inspect their exact inputs with `--help` and preserve the
changed-set cursor as the authority.

## MCP and browser sessions

```bash
repo-harness mcp doctor --repo "$PWD" --json
repo-harness mcp workspaces list --json
repo-harness chatgpt browser-list --repo . --json
repo-harness chatgpt browser-cleanup --repo . --json
```

Browser cleanup is a dry-run unless `--force` is supplied. `browser-followup`
creates a linked session; `browser-session` reads saved output; `browser-open`
prints a saved conversation URL for a completed real browser session and launches
it only with `--launch`. Dry-run sessions have no conversation URL.
