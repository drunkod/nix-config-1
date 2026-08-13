# Everyday developer recipes

Short workflows built on the configured `m1-min` stack: Repo Harness, ChatGPT
Coding MCP, Browser Engine, CodeGraph, Graphify, and the local Gitingest CLI.

Read the shared [`safety rules`](../repo-harness/safety.md) once; individual
recipes do not repeat them.

| Task | Recipe |
|---|---|
| Build a reusable context packet for ChatGPT | [Context packet](01-context-packet.md) |
| Understand an unfamiliar feature quickly | [Explore unfamiliar code](02-explore-unfamiliar-code.md) |
| Diagnose a bug and define the fix boundary | [Bug diagnosis](03-bug-investigation.md) |
| Plan a refactor and identify blast radius | [Refactor planning](04-refactor-planning.md) |
| Review a branch or PR with focused context | [PR review](05-pr-review.md) |
| Save progress and hand work to another session | [Handoff packet](06-handoff-packet.md) |
| Implement and package an approved bug fix | [Bug-fix implementation packet](07-bug-patch-locator.md) |
| Choose regression tests from a patch | [Regression-test packet](08-regression-test-packet.md) |
| Map a dependency upgrade before changing versions | [Dependency upgrade map](09-dependency-upgrade-map.md) |
| Trace a schema/API/event change across layers | [Cross-layer contract change](10-cross-layer-contract-change.md) |
| Turn a branch into PR, release, and handoff context | [Release change capsule](11-release-change-capsule.md) |

## Shared index preflight

Run before a recipe that uses both graph tools:

```bash
if test -d "$PWD/.codegraph"; then
  codegraph sync "$PWD"
else
  codegraph init "$PWD"
fi

if test -s "$PWD/graphify-out/graph.json" &&
   test -s "$PWD/graphify-out/manifest.json"; then
  graphify-update "$PWD"
else
  graphify-extract "$PWD" --code-only
fi
```

CodeGraph and Graphify keep separate state for each repository/worktree. The
default Graphify wrappers build an unclustered code graph, so recipes ask about
callers, dependencies, paths, and impact rather than communities.

## Choose the ChatGPT surface

| Surface | How context enters | Can edit source? |
|---|---|---:|
| Normal ChatGPT chat | Manually attach reviewed files | No local tools unless an app is selected |
| Browser Engine | Explicit `--file` attachments and prompt | Writes only requested output/session artifacts |
| Repo Harness Coding MCP | Repository discovery, managed workspace, `read`/`apply_patch`/`exec_command` | Yes, after explicit `read_write` grant |

Do not assume a file attached to normal ChatGPT is automatically available to
Coding MCP, or vice versa.

## Choose a context tool

- **Gitingest:** broad local repository digest.
- **CodeGraph:** focused source, symbols, call paths, and impact.
- **Graphify:** explicit graph traversal, dependencies, paths, and impact.

## Suggested local context directory

Use an ignored directory:

```bash
mkdir -p .ai/context-packets
```

Add it to `.gitignore` and `.ignore` when appropriate:

```gitignore
.ai/context-packets/
```

Review generated packets before sharing; cleanup and external-service rules are
in the shared [`safety guide`](../repo-harness/safety.md).

For an exact-file digest, put one repository-relative path per line and run:

```bash
"$HOME/nix-config/scripts/gitingest-selected.sh" \
  "$PWD" packet-files.txt packet.md
```

The helper preserves paths containing spaces, skips deleted files, and stops
instead of falling back to a full-repository digest when the selection is empty.
