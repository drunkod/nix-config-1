---
name: graphify
description: Use when the user wants to build, refresh, query, traverse, export, or diagnose a repository-scoped Graphify graph. Default to deterministic code-only extraction, explicit graph identity, and the m1-min wrappers.
---

# Graphify: repository-scoped workflow

Version scope: Graphify revision
`0b2bd938c4a48e91d27f0ba09b96409e0a36c78a`, pinned by this repository.
Check `graphify --help` before advanced/version-sensitive commands.

## Safety invariant

One query or MCP process must use one identified graph from one repository or
worktree:

```text
<project>/graphify-out/graph.json
```

Fail when project identity is ambiguous. Never select a different repository,
hard-coded fallback, or saved global graph unless the user explicitly asks for
saved mode.

## Default `m1-min` commands

```bash
graphify-extract /absolute/project --code-only
graphify-update /absolute/project
graphify-query "concrete symbols and relationships" \
  --graph /absolute/project/graphify-out/graph.json
graphify-mcp-find-graph
graphify-mcp-run /absolute/project/graphify-out/graph.json
```

The same commands are available as flake apps under `~/nix-config`.

Important:

- `graphify-extract` is the initial/clean-build path and accepts `--code-only`;
- `graphify-update` is the code refresh path and does **not** accept
  `--code-only`;
- update must preserve existing `graph.json` and `manifest.json`;
- use `--force` only after deliberate large deletions/refactors or when the CLI
  requests a node-ID rebuild;
- restart MCP after changing the graph.

## Code-only policy

Before extraction, ensure `.graphifyignore` excludes:

- `graphify-out/`;
- dependencies, generated output, and vendor trees;
- prose and structured documents;
- PDFs and office files;
- images, audio, and video.

A healthy offline extraction reports code and zero documents, papers, and
images. Do not add API keys, semantic providers, media tools, or heavier extras
unless the user explicitly requests that workflow and accepts network/privacy
implications.

## MCP modes

### Automatic mode

`graphify-mcp-auto` resolves only:

1. valid `GRAPHIFY_GRAPH_PATH`;
2. valid `GRAPHIFY_PROJECT_ROOT`;
3. exactly `<nearest-git-root>/graphify-out/graph.json`;
4. otherwise failure.

It does not scan arbitrary ancestors, climb above the Git root, read saved
state, or use fallback repositories. Use `graphify-mcp-find-graph` to inspect
selection.

### Explicit mode — preferred for GUI/project configuration

```bash
graphify-mcp-run /absolute/project/graphify-out/graph.json
```

Use explicit mode for Zed multi-root workspaces, containers, CI, sandboxes, or
any client whose working directory is unreliable.

### Saved mode — exceptional and deliberate

```bash
graphify-mcp-set-graph /absolute/project
graphify-mcp-set-graph --show
graphify-mcp-saved
graphify-mcp-set-graph --clear
```

Never use saved mode as automatic project switching.

## Query and traversal

Prefer concrete graph vocabulary: files, classes, functions, modules, packages,
services, and known relationships. Use:

- `graphify-query` for BFS/DFS textual traversal;
- MCP `query_graph`, `get_node`, `get_neighbors`, and `shortest_path` for exact
  structured relationships;
- `graphify affected`, `god-nodes`, `path`, and `explain` only after checking
  current root help.

Verify important implementation details in source after graph traversal. Never
invoke `graphify-out/.graphify_python` or manually reproduce Graphify's internal
extraction, manifest, merge, pruning, or clustering pipeline.

## Worktrees and freshness

Every Git worktree owns a separate `graphify-out/`. After branch switches or
edits:

```bash
graphify-update /absolute/project
```

For a clean rebuild:

```bash
graphify-extract /absolute/project --code-only --force
```

## Nix-free sandbox

```bash
bash /workspace/nix-config/scripts/graphify-sandbox.sh extract \
  /workspace/project --code-only
bash /workspace/nix-config/scripts/graphify-sandbox.sh update /workspace/project
bash /workspace/nix-config/scripts/graphify-sandbox.sh query \
  "concrete symbols" \
  --graph /workspace/project/graphify-out/graph.json
bash /workspace/nix-config/scripts/graphify-sandbox.sh mcp \
  /workspace/project/graphify-out/graph.json
```

For offline use, mount the locked source and set `GRAPHIFY_SOURCE_DIR`. Never
copy saved state or mutable graphs between the Mac and a sandbox.

## Imperative installer policy

The `m1-min` profile manages global skills and MCP configuration declaratively.
Do not run `graphify install`, `graphify claude install`, `graphify codex
install`, or similar global/project mutations unless the user explicitly asks
for that repository-local integration and understands the generated-file
changes.

## Reference sidecars

Load only the relevant, version-scoped sidecar:

- `references/query.md` — query/path/explain/affected/god-nodes;
- `references/update.md` — update, force rebuild, and clustering;
- `references/exports.md` — verified export and explicit MCP behavior;
- `references/github-and-merge.md` — clone and explicit graph merge;
- `references/add-watch.md` — opt-in URL ingestion and watch mode;
- `references/transcribe.md` — opt-in media transcription constraints;
- `references/extraction-spec.md` — supported extraction contract;
- `references/hooks.md` — opt-in Git/agent hook behavior.

The canonical user guide is `docs/graphify-new-repository.md`.
