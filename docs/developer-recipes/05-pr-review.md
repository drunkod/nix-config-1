# Recipe 5: review a branch or pull request

Use this to review behavior and blast radius, not just style. Shared rules:
[`Repo Harness safety`](../repo-harness/safety.md).

## 1. Capture the change surface

```bash
git fetch origin
BASE=origin/main

git diff --stat "$BASE"...HEAD
git diff --name-status "$BASE"...HEAD
git log --oneline "$BASE"..HEAD
```

Do not check out untrusted code merely to read a remote PR unless your workflow
requires it and you understand repository hooks/build scripts.

## 2. Find affected behavior

Run the shared [index preflight](README.md#shared-index-preflight), then:

```bash
git diff --name-only "$BASE"...HEAD |
codegraph affected --path "$PWD" --stdin
```

For the main changed symbols:

```bash
codegraph explore \
  "Review the changed <symbols/files>: callers, behavioral impact, and missing tests" \
  --path "$PWD" \
  --max-files 15
```

## 3. Add graph context when needed

```bash
nix shell nixpkgs#coreutils --command \
  graphify affected "<changed abstraction>" \
  --depth 2 \
  --graph "$PWD/graphify-out/graph.json"
```

## 4. Build a review packet

Include only:

- PR goal and acceptance criteria;
- commit list;
- diff/stat or reviewed patch;
- focused CodeGraph/Graphify conclusions;
- affected tests;
- CI failures;
- repository instructions.

A full Gitingest dump is usually unnecessary for review. Use it only when the
reviewer cannot access the repository and the source is safe to send externally.

## 5. Run an opposite-provider review

Use Codex when Claude produced the change, or Claude when Codex produced it:

```bash
repo-harness cross-review \
  --repo "$PWD" \
  --base "$BASE" \
  --provider codex \
  --json
```

Treat provider output as review evidence, not automatic approval.

## 6. Ask ChatGPT for high-signal findings

```text
Review for definite correctness, security, data-loss, compatibility, and missing
validation issues. Ignore subjective style. Tie every finding to changed code and
state severity, evidence, and a concrete fix. Do not post comments or modify GitHub.
```

Use normal ChatGPT attachments, Browser Engine, or the GitHub app in read-only
mode. Require visible tool events when relying on a connector.

## 7. Verify each finding locally

Before posting review comments:

- reproduce or trace the issue;
- confirm it is introduced by the change;
- confirm repository instructions support the claim;
- avoid duplicate comments;
- separate “must fix” from optional follow-up.

Posting comments, resolving threads, rerunning CI, approving, and merging are
separate write actions.
