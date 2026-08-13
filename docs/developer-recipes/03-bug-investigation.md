# Recipe 3: diagnose a bug and define the fix boundary

Use this to move from a symptom to a reproduced root cause and approved fix boundary. Shared rules:
[`Repo Harness safety`](../repo-harness/safety.md).

## 1. Record the symptom

Create a local brief:

```markdown
# Bug

- Observed behavior:
- Expected behavior:
- Reproduction steps:
- Error/log excerpt:
- Environment:
- Last known good version:
- Suspected area:
```


## 2. Trace the failing flow

Run the shared [index preflight](README.md#shared-index-preflight), then:

```bash
codegraph explore \
  "Trace the code path that produces <error/symptom>; include callers, error handling, and tests" \
  --path "$PWD" \
  --max-files 12
```

If you know two endpoints of the flow, use the refreshed Graphify graph to find
the relationship:

```bash
graphify-query \
  "path from <entry symbol> to <failure symbol>" \
  --graph "$PWD/graphify-out/graph.json" \
  --budget 2000
```

## 3. Reproduce before editing

Use a normal terminal or an approved Coding MCP `exec_command` in a managed
workspace. Run the smallest deterministic command that demonstrates the bug.
Capture:

```text
command
exit code
relevant failing lines
```

Do not change code merely because a static explanation looks plausible.

## 4. Ask ChatGPT for hypotheses

Provide the bug brief, focused CodeGraph result, and reproduction evidence:

```text
Rank the likely root causes. For each, cite evidence and give one discriminating
test. Do not implement a fix yet.
```

## 5. Define the fix boundary

```markdown
Goal: fix the reproduced failure
Allowed paths: exact source/test files
Forbidden paths: everything else
Required regression test: exact test
Validation: exact command
Stop after: show diff and test result; do not commit or push
```

## 6. Hand off implementation

Record the reproduced root cause, exact patch/test boundary, validation command,
and unresolved assumptions. Then continue with
[Recipe 7: implement and package the bug fix](07-bug-patch-locator.md).
