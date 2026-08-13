# 2. Initialize CodeGraph for a repository

Use this guide after the repository is adopted and committed. CodeGraph is
optional semantic navigation and post-mutation indexing. It is not a Repo
Harness authorization boundary and does not replace `.ignore` or managed
workspace containment. Shared rules:
[`Repo Harness safety`](../safety.md).

## What Nix already owns

On `m1-min`, Home Manager:

- installs CodeGraph from `llm-agents.nix`;
- registers `codegraph serve --mcp` through the shared MCP registry;
- distributes that MCP configuration to the configured agents.

Do not run:

```text
codegraph install
codegraph upgrade
curl .../install.sh | sh
npm install -g @colbymchenry/codegraph
```

Those commands would modify agent or CLI state outside the Nix configuration.
Project indexing is separate and is allowed.

## Step 1: verify the Nix-managed CLI

```bash
command -v codegraph
codegraph version
```

The tested `m1-min` configuration uses CodeGraph `1.5.0`.

## Step 2: verify the project boundary

Run from the canonical source checkout:

```bash
cd /absolute/path/to/repository

git rev-parse --show-toplevel
git status --short --branch
```

Confirm `.codegraph/` is ignored by Git:

```bash
git check-ignore -v .codegraph/ || true
```

If no rule is reported, add this project-state rule to `.gitignore` before
initializing:

```gitignore
.codegraph/
```

CodeGraph also honors `.gitignore` and built-in dependency/build exclusions.
Use a committed `codegraph.json` only when the repository needs additional
tracked-source exclusions, includes, or custom extensions.

## Step 3: initialize the source checkout

Pass the exact project path:

```bash
codegraph init /absolute/path/to/repository
```

`init` creates `.codegraph/` and builds the initial graph in one operation.
Installing the CLI does not initialize projects automatically.

Do not run `init` simultaneously for the same project from multiple terminals.
Do not copy an index from another repository or worktree.

## Step 4: verify the index

```bash
codegraph status /absolute/path/to/repository
```

For machine-readable inspection:

```bash
codegraph status /absolute/path/to/repository --json
```

Require an initialized project and a readable local database. If indexing fails,
fix exclusions or supported-language issues before using CodeGraph for structural
claims.

Run one harmless query:

```bash
codegraph explore \
  "Summarize the top-level architecture" \
  --path /absolute/path/to/repository
```

Verify important results against current source when they affect a code change.

## Step 5: synchronize after Git changes

The MCP server watches files while running, but an explicit sync is the reliable
preflight after branch operations or changes made while no server was running:

```bash
codegraph sync /absolute/path/to/repository
codegraph status /absolute/path/to/repository
```

Use this after:

- branch switches;
- pulls, merges, or rebases;
- large generated changes;
- file changes made while CodeGraph MCP was not running.

Do not repeat a source mutation because an index refresh failed. The source write
and CodeGraph refresh are separate outcomes.

## Critical distinction: source checkout versus managed worktree

Every Git worktree needs its own `.codegraph/` index. An index created in:

```text
/absolute/path/to/repository/.codegraph/
```

is not copied into a Repo Harness managed worktree because `.codegraph/` is
ignored local state.

At the tested Repo Harness revision:

- `open_workspace` creates a managed Git worktree but does not initialize,
  copy, or sync CodeGraph;
- post-`apply_patch` refresh checks the managed worktree root, not the source
  checkout;
- initializing only the source checkout does not prevent
  `CodeGraph index is not initialized for this repo` in worktree mode.

Therefore, after opening each new managed workspace and before its first patch,
run one explicitly approved workspace command through Repo Harness:

```text
codegraph init .
```

Optional verification in the same workspace:

```text
codegraph status . --json
```

This requires `exec_command`, which has local-user shell authority. Review and
approve the exact command. Do not combine it with unrelated setup, package
installation, Git mutation, or source edits.

If `codegraph init .` reports that the index already exists, use:

```text
codegraph sync .
```

Do not ask ChatGPT to discover or reveal the opaque managed-worktree filesystem
path. `exec_command` starts in the selected workspace and should use `.`.

## Why the initialization must precede the first patch

A live validation produced this result:

```text
apply_patch source mutation:  succeeded
CodeGraph index refresh:      failed
error: CodeGraph index is not initialized for this repo
```

The patch must not be repeated: the file already exists. Initialize/sync the
workspace index separately, then continue with validation or the next mutation.

## Checkout mode is not the default workaround

A source-checkout index is visible when Repo Harness uses `mode: checkout`, but
that mode edits the existing checkout and removes the normal managed-worktree
isolation boundary. Do not switch to checkout mode merely to reuse CodeGraph.
Prefer managed worktree mode plus an explicit `codegraph init .` in each new
workspace.

## CodeGraph is not a security boundary

- Repo Harness grants access; CodeGraph does not.
- `.ignore` and path containment protect repository reads/writes; CodeGraph does
  not.
- A CodeGraph index must never be used to bypass a denied file read.
- Do not index secrets or private operational trees.
- CodeGraph and Graphify remain separate per-project systems.

## Completion checklist

```text
[ ] Nix-managed codegraph command resolves
[ ] source repository contains .codegraph/ in local ignored state
[ ] codegraph status reports an initialized index
[ ] harmless source-checkout query succeeds
[ ] each managed worktree is initialized separately before its first patch
[ ] failed index refresh never causes a repeated source mutation
```

Continue with [guide 3: start Coding MCP and Quick Tunnel](03-start-coding-mcp-quick-tunnel.md).
For detailed behavior, see the [CodeGraph workflow](../../tools/codegraph.md).
