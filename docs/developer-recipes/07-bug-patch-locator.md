# Recipe 7: implement and package a diagnosed bug fix

Use this after Recipe 3 has reproduced the bug and approved the patch boundary.
Run the shared [index preflight](README.md#shared-index-preflight). Shared rules:
[`Repo Harness safety`](../repo-harness/safety.md).

## 1. Confirm the approved patch location

```bash
mkdir -p .ai/context-packets/bug-name

codegraph explore \
  "Trace <symptom/error> from its entry point to the likely root cause. Name the exact symbols, files, and tests that should change." \
  --path "$PWD" \
  --max-files 12 \
  > .ai/context-packets/bug-name/01-codegraph-locator.md
```

Add architectural relationships when the flow crosses modules:

```bash
nix shell nixpkgs#coreutils --command \
  graphify-query \
  "<entry symbol> <failure symbol> callers dependencies tests" \
  --graph "$PWD/graphify-out/graph.json" \
  --budget 2000 \
  > .ai/context-packets/bug-name/02-graphify-path.md
```

## 2. Ask ChatGPT for a patch boundary

Attach the two locator files and ask:

```text
Identify the smallest root-cause patch. Return exact files/symbols, one
regression test, validation commands, and assumptions to verify. Do not patch.
```

Verify the proposed location against current source before editing.

## 3. Apply and validate the patch

Use Coding MCP or your normal editor. After validation, refresh CodeGraph:

```bash
codegraph sync "$PWD"
```

## 4. Find the changed and affected files

```bash
{
  git diff HEAD --name-only
  git ls-files --others --exclude-standard
} | awk '
  !/^\.ai\// &&
  !/^\.codegraph\// &&
  !/^graphify-out\//
' | sort -u > .ai/context-packets/bug-name/changed-files.txt

codegraph affected \
  --path "$PWD" \
  --stdin \
  --json \
  < .ai/context-packets/bug-name/changed-files.txt \
  > .ai/context-packets/bug-name/03-affected-tests.json
```

## 5. Check workflow and create a focused digest

For Standard/Strict work, run the configured workflow check:

```bash
repo-harness run check-task-workflow -- --strict
```

Digest the reviewed changed-file list using GNU coreutils on macOS:

```bash
nix shell nixpkgs#coreutils --command \
  "$HOME/nix-config/scripts/gitingest-selected.sh" \
  "$PWD" \
  .ai/context-packets/bug-name/changed-files.txt \
  .ai/context-packets/bug-name/04-patched-files.md
```

Attach `01-codegraph-locator.md`, `02-graphify-path.md`,
`03-affected-tests.json`, and `04-patched-files.md` for final review. This gives
the reviewer the original path hypothesis, architectural context, affected tests,
and exact post-patch source without a full-repository dump.
