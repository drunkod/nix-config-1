# Recipe 12: refresh capability-local agent context

Use this after changing a capability boundary, moving important files, or finding
that local `CLAUDE.md` / `AGENTS.md` guidance is stale. Shared rules:
[`Repo Harness safety`](../repo-harness/safety.md).

## 1. Inspect configured context

```bash
repo-harness capability-context status \
  --repo "$PWD" \
  --json
```

If the capability registry or source-map manifest is absent, this repository is
not configured for capability-local context.

## 2. Resolve one changed path

```bash
repo-harness capability-context request \
  --repo "$PWD" \
  --path path/to/changed-file \
  --json
```

For architecture-driven work, request from the latest architecture event instead:

```bash
repo-harness capability-context request \
  --repo "$PWD" \
  --from-latest-architecture-event \
  --json
```

## 3. Preview generated context

```bash
repo-harness capability-context sync \
  --repo "$PWD" \
  --path path/to/changed-file \
  --dry-run \
  --json
```

For queued requests:

```bash
repo-harness capability-context sync \
  --repo "$PWD" \
  --pending \
  --dry-run \
  --json
```

Review which capability and context files would change. Apply only after the
preview is correct by replacing `--dry-run` with `--apply`.

## 4. Verify the result

```bash
repo-harness capability-context status --repo "$PWD" --json
git diff -- CLAUDE.md AGENTS.md '*/CLAUDE.md' '*/AGENTS.md'
```

Then use CodeGraph or Graphify to verify the generated guidance still matches the
actual capability boundary.
