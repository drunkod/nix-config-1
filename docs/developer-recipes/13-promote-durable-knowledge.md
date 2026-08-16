# Recipe 13: promote durable project knowledge

Use this when a completed task produced a reusable decision, runbook, pattern, or
reference. Repo Harness brain operations are explicit and manifest-controlled.
Shared rules: [`Repo Harness safety`](../repo-harness/safety.md).

## 1. Inspect the manifest and destination

```bash
repo-harness brain status \
  --repo "$PWD" \
  --json
repo-harness brain check \
  --repo "$PWD" \
  --json
```

If no brain root or manifest is configured, keep the knowledge in repository
artifacts instead of inventing a destination.

## 2. Preview normal synchronization

```bash
repo-harness brain sync \
  --repo "$PWD" \
  --dry-run \
  --json
```

Limit a preview to one changed path when appropriate:

```bash
repo-harness brain sync \
  --repo "$PWD" \
  --changed docs/researches/topic.md \
  --dry-run \
  --json
```

Review the planned source and destination files before running the same command
without `--dry-run`.

## 3. Promote an archived workflow lesson

After a workflow is archived, preview promotion by slug:

```bash
repo-harness brain promote \
  --repo "$PWD" \
  --slug completed-workflow-slug \
  --category patterns \
  --dry-run \
  --json
```

Valid categories are `decisions`, `runbooks`, `patterns`, and `references`.
Repeat without `--dry-run` only after reviewing the archived plan and notes.

## 4. Recheck drift

```bash
repo-harness brain check --repo "$PWD" --json
```

Keep sprint evidence in reviews and handoffs. Promote only knowledge that remains
useful beyond the completed task.
