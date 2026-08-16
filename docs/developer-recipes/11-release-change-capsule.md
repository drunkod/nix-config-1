# Recipe 11: create a release change capsule

Use this to explain what a branch changes without attaching the whole repository.
Run the shared [index preflight](README.md#shared-index-preflight). Shared rules:
[`Repo Harness safety`](../repo-harness/safety.md).

## 1. Record exact branch evidence

```bash
mkdir -p .ai/context-packets/release

BASE=origin/main
git log --oneline "$BASE"..HEAD \
  > .ai/context-packets/release/commits.txt
git diff --stat "$BASE"...HEAD \
  > .ai/context-packets/release/diff-stat.txt
git diff --name-only "$BASE"...HEAD \
  > .ai/context-packets/release/changed-files.txt
```

## 2. Explain behavior, not just filenames

```bash
changed_files=$(sed 's/^/- /' \
  .ai/context-packets/release/changed-files.txt)

codegraph explore \
  "Explain the user-visible and internal behavior changed by these files; identify entry points, callers, and affected tests:
$changed_files" \
  --path "$PWD" \
  --max-files 15 \
  > .ai/context-packets/release/behavior-summary.md
```

## 3. Detect architectural movement

```bash
nix shell nixpkgs#coreutils --command \
  graphify-query \
  "<main changed symbols> callers dependency paths architecture impact" \
  --graph "$PWD/graphify-out/graph.json" \
  --budget 2000 \
  > .ai/context-packets/release/architecture-impact.md
```

## 4. Add Repo Harness architecture state when configured

If `.ai/harness/policy.json` exists:

```bash
repo-harness architecture-projection status --json \
  > .ai/context-packets/release/architecture-projection-status.json
repo-harness architecture-projection drain --json \
  > .ai/context-packets/release/architecture-projection-drain.json
```

Failed or unavailable projection remains pending in `0.15.0`; do not rewrite or
manually acknowledge it as clean. If the policy file is absent, omit these files.

## 5. Digest exactly the final changed files

```bash
nix shell nixpkgs#coreutils --command \
  "$HOME/nix-config/scripts/gitingest-selected.sh" \
  "$PWD" \
  .ai/context-packets/release/changed-files.txt \
  .ai/context-packets/release/final-source.md
```

## 6. Add workflow and merge evidence

For a Standard/Strict release candidate:

```bash
repo-harness run check-task-workflow -- --strict
repo-harness cross-review \
  --repo "$PWD" \
  --base "$BASE" \
  --provider codex \
  --json
repo-harness run merge-gate -- \
  run \
  --base "$BASE" \
  --format json
```

Choose the opposite review provider. `ship-worktrees` is a separate authorized
write because it commits, pushes, and opens draft PRs.

## 7. Generate multiple outputs from one capsule

Attach the capsule and ask ChatGPT for any of:

- a PR description with test evidence;
- release notes grouped by user-visible behavior;
- a reviewer briefing focused on risk;
- a support-team summary of changed behavior;
- a handoff for the next developer.

Because the capsule is tied to `"$BASE"...HEAD`, regenerate it after the branch
changes rather than editing its generated files manually.
