# Recipe 8: build a regression-test packet from a change

Use this when a patch exists but test coverage is uncertain. Run the shared
[index preflight](README.md#shared-index-preflight). Shared rules:
[`Repo Harness safety`](../repo-harness/safety.md).

## 1. Capture the change surface

```bash
mkdir -p .ai/context-packets/regression

BASE=origin/main
git diff --name-only "$BASE"...HEAD \
  > .ai/context-packets/regression/changed-files.txt
```

## 2. Ask CodeGraph which tests are affected

```bash
codegraph affected \
  --path "$PWD" \
  --stdin \
  --json \
  < .ai/context-packets/regression/changed-files.txt \
  > .ai/context-packets/regression/affected-tests.json

changed_files=$(sed 's/^/- /' \
  .ai/context-packets/regression/changed-files.txt)

codegraph explore \
  "For these changed files, identify behavior branches with no direct regression test:
$changed_files" \
  --path "$PWD" \
  --max-files 12 \
  > .ai/context-packets/regression/test-gaps.md
```

## 3. Check cross-module effects with Graphify

```bash
graphify-query \
  "<changed symbols> tests consumers dependency paths" \
  --graph "$PWD/graphify-out/graph.json" \
  --budget 1800 \
  > .ai/context-packets/regression/graph-impact.md
```

Initialize or update Graphify first when needed.

## 4. Digest only implementation and candidate tests

Create `packet-files.txt` by combining the reviewed changed paths and candidate
test paths. Then:

```bash
"$HOME/nix-config/scripts/gitingest-selected.sh" "$PWD" \
  .ai/context-packets/regression/packet-files.txt \
  .ai/context-packets/regression/source-and-tests.md
```

## 5. Ask for the smallest useful test set

```text
Using the changed source, candidate tests, CodeGraph affected-test result, and
Graphify impact, propose the minimum regression tests that cover the behavioral
risk. Separate existing tests to run from new tests to add.
```
