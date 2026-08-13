# Recipe 14: iterate on a saved Browser Engine consultation

Use this when a planning or review question needs several focused passes without
rebuilding context from scratch. Shared rules:
[`Repo Harness safety`](../repo-harness/safety.md).

## 1. Start with a dry-run

```bash
repo-harness chatgpt browser-consult \
  --repo . \
  --provider oracle \
  --dry-run \
  --prompt "Review the attached design and list unresolved decisions." \
  --file docs/spec.md
```

Record the returned session ID. Review the generated prompt, then repeat without
`--dry-run` for a real browser consultation.

## 2. Inspect saved sessions

```bash
repo-harness chatgpt browser-list \
  --repo . \
  --limit 10 \
  --json
repo-harness chatgpt browser-session \
  --repo . \
  --metadata-only \
  <session-id>
```

## 3. Create a linked follow-up

Preview the follow-up first:

```bash
repo-harness chatgpt browser-followup \
  --repo . \
  --session <session-id> \
  --provider oracle \
  --dry-run \
  --prompt "Challenge the preferred option and identify one cheaper alternative."
```

The follow-up inherits the prior conversation link. Repeat without `--dry-run`
only after reviewing the prompt.

## 4. Reopen or clean up

After a real browser run, print the saved conversation URL without launching a
browser:

```bash
repo-harness chatgpt browser-open --repo . <session-id>
```

Dry-run sessions intentionally have no conversation URL.

Preview old-session cleanup:

```bash
repo-harness chatgpt browser-cleanup \
  --repo . \
  --older-than-days 30 \
  --json
```

Cleanup deletes only when the same reviewed selection is run with `--force`.
