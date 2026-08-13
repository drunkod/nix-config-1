# Recipe 6: create a durable handoff packet

Use this when work must continue in another session, agent, machine, or day.
Shared rules: [`Repo Harness safety`](../repo-harness/safety.md).

## 1. Capture exact repository state

```bash
git status --short --branch
git rev-parse HEAD
git log -5 --oneline
```

Record active managed workspace IDs/branches without exposing opaque local paths.

## 2. Refresh code intelligence

For the canonical checkout or current worktree, run the shared
[index preflight](README.md#shared-index-preflight), then record CodeGraph state:

```bash
codegraph status "$PWD" --json
```

Do not copy index directories into the handoff.

## 3. Write the handoff

Use a tracked workflow path when the handoff belongs in the repository:

```text
.ai/harness/handoff/current.md
```

Or a local ignored packet for temporary/private work:

```text
.ai/context-packets/<task>/handoff.md
```

Template:

```markdown
# Handoff

## Goal

## Current branch and exact SHA

## What changed

## Files changed

## Validation run

## Current failures

## Decisions and constraints

## CodeGraph/Graphify state

## Managed workspace state

## Next exact step

## Do not do

## Secrets/private state not included
```

## 4. Add focused context only

Optionally include:

- one CodeGraph exploration result;
- one Graphify query/report;
- a reviewed diff/stat;
- relevant reviewed logs;
- acceptance criteria.

Do not attach entire repository dumps when the next agent has repository access.
A large Gitingest file is useful only for disconnected review or external chat.

## 5. Prepare Repo Harness recovery views

Read the next continuation unit, then generate the appropriate handoff artifact:

```bash
repo-harness state next --json
repo-harness run prepare-handoff
repo-harness run prepare-codex-handoff
```

The continuation envelope is read-only workflow state authorizing one bounded
unit. Attempt receipts are liveness evidence, not workflow authority. After one unit,
record the progress tokens from the before/after envelopes:

```bash
repo-harness state attempt \
  --unit-ref plans/path-to-active-plan.md \
  --outcome completed \
  --before-progress-token '<token-from-before-envelope>' \
  --after-progress-token '<token-from-after-envelope>' \
  --json
```

On the receiving side, forward helper arguments after `--`:

```bash
repo-harness run codex-handoff-resume -- --help
repo-harness run codex-handoff-resume -- \
  --cwd "$PWD" \
  --print-prompt
```

Use `repo-harness run --help` if a helper disappears in a later release.

## 6. Handoff prompt

```text
Resume from the attached handoff. First verify branch, SHA, working-tree state,
and applicable instructions. Do not repeat completed mutations. Reproduce the
current failure or run the stated next check before editing.
```

## 7. Final check

Confirm the handoff states the exact next step and links only reviewed evidence.
