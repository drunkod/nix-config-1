---
name: graphify
description: Use when the user wants to map, index, understand, refresh, or query a local codebase or an existing graphify-out knowledge graph. Covers architecture, dependencies, callers, neighbours, paths, exports, and Graphify MCP traversal. Prefer deterministic code-only extraction and always bind MCP/query work to one explicit repository graph.
---

# Graphify: repository-scoped usage

Graphify builds a local graph for one repository under
`<project>/graphify-out/graph.json`. Never treat it as a global cross-project
database.

For code-only corpora, extraction is deterministic and local through
tree-sitter. Documents, PDFs, images, audio, and video can trigger semantic or
transcription providers, so exclude them unless the user explicitly requests
that workflow.

## Non-negotiable safety rule

One query or MCP process must use one identified graph.

Do not select a graph from:

- a different repository;
- a hard-coded fallback directory;
- mutable saved global state unless the user explicitly requests saved mode.

When project context is unclear, fail rather than silently using another graph.

## Installed system commands

The user's `m1-min` configuration exposes:

- `graphify-extract <project>` — create a fresh graph;
- `graphify-update <project>` — incrementally refresh an existing graph;
- `graphify-query ... --graph <graph.json>` — query an explicit graph;
- `graphify-mcp-find-graph` — inspect project-scoped automatic selection;
- `graphify-mcp-auto` — use environment/project/PWD context only;
- `graphify-mcp-run <project-or-graph>` — use one explicit graph;
- `graphify-mcp-set-graph` — manage deliberate saved state;
- `graphify-mcp-saved` — explicitly launch the saved graph;
- `graphify-mcp` — low-level upstream wrapper.

The same commands are available as flake apps from the user's `nix-config`
checkout. Common locations are `~/nix-config` and `~/.setup`.

Examples:

```bash
nix run ~/nix-config#graphify-extract -- /path/to/project
nix run ~/nix-config#graphify-update -- /path/to/project
nix run ~/nix-config#graphify-query -- \
  "what calls RuntimeBridge" \
  --graph /path/to/project/graphify-out/graph.json
```

Prefer installed commands when the Home Manager profile is active. Prefer
explicit flake commands when command availability is uncertain.

## Core workflow

1. Identify the exact project root.
2. Confirm `.graphifyignore` excludes non-code inputs and generated/vendor trees.
3. If no graph exists, run `graphify-extract <project>`.
4. If a graph exists but source changed, run `graphify-update <project>`.
5. Confirm `graphify-out/graph.json` belongs to the target project.
6. Query that exact path or start MCP with that exact project/graph.
7. Use source reads only to verify implementation details after graph traversal.

Do not run `graphify-update` before the first graph exists. Do not delete
`graph.json` or `manifest.json` before an incremental update.

## Offline code-only policy

A healthy offline extraction reports zero documents, papers, and images.

If non-code categories are detected:

1. tighten `.graphifyignore`;
2. rerun extraction;
3. do not add API keys or semantic extras unless explicitly requested.

Typical exclusions include:

```gitignore
*.md
*.txt
*.yaml
*.yml
*.pdf
*.docx
*.png
*.jpg
*.svg
*.mp4

graphify-out/
.venv/
node_modules/
dist/
build/
target/
docs/
assets/
```

## Query policy

Use `graphify-query` for scoped questions with concrete graph terms: file names,
modules, classes, functions, packages, services, or directories.

Good:

```bash
graphify-query \
  "what depends on RuntimeBridge" \
  --graph "$PROJECT/graphify-out/graph.json"
```

Avoid treating it as an unconstrained general-purpose prompt engine. For broad
architecture questions:

1. inspect `GRAPH_REPORT.md` when present;
2. inspect graph nodes, edges, top-level directories, and communities;
3. identify concrete entities;
4. run targeted queries, paths, explains, or MCP traversal;
5. verify important claims in source.

## MCP policy

### Automatic project mode

`graphify-mcp-auto` resolves only:

1. valid `GRAPHIFY_GRAPH_PATH`;
2. valid `GRAPHIFY_PROJECT_ROOT`;
3. `graphify-out/graph.json` found upward from the process working directory.

It never reads saved global state and never uses unrelated fallback
repositories.

Before automatic startup, inspect selection with:

```bash
graphify-mcp-find-graph
```

An invalid explicit environment path must fail immediately. Do not fall back.

### Explicit mode — preferred

For GUI programmes, Claude project configuration, CI, containers, and
sandboxes, use:

```bash
graphify-mcp-run /absolute/project/graphify-out/graph.json
```

This is the preferred MCP mode because the graph identity is visible in the
configuration.

### Saved mode — only by explicit request

Only use this workflow when the user deliberately wants a single global graph:

```bash
graphify-mcp-set-graph /absolute/project
graphify-mcp-set-graph --show
graphify-mcp-saved
graphify-mcp-set-graph --clear
```

Never use `graphify-mcp-set-graph` as an automatic project-switching mechanism.

### Structured traversal

Use MCP/direct graph tools for exact relationships, including:

- `query_graph`;
- `get_node`;
- `get_neighbors`;
- `shortest_path`.

Prefer these for exact calls, dependencies, neighbours, and path questions.

## Claude Code sandbox without Nix

The repository provides:

```text
scripts/graphify-sandbox.sh
```

Use it through Bash:

```bash
bash /workspace/nix-config/scripts/graphify-sandbox.sh extract /workspace/project
bash /workspace/nix-config/scripts/graphify-sandbox.sh update /workspace/project
bash /workspace/nix-config/scripts/graphify-sandbox.sh query \
  "what calls RuntimeBridge" \
  --graph /workspace/project/graphify-out/graph.json
bash /workspace/nix-config/scripts/graphify-sandbox.sh mcp \
  /workspace/project/graphify-out/graph.json
```

The launcher requires `uv`; it uses the Graphify revision pinned by this
repository. For an offline sandbox, mount a source checkout and set:

```bash
export GRAPHIFY_SOURCE_DIR=/workspace/vendor/graphify
```

Never copy the Mac's saved MCP state into a sandbox. Configure the sandbox MCP
server with an explicit graph path.

## Reports and diagrams

If `GRAPH_REPORT.md` is absent and a readable architecture view is required,
use an offline report/export path supported by the installed CLI. Verify
version-sensitive commands with `graphify --help` first.

Inside the Graphify development shell, examples may include:

```bash
graphify cluster-only . --no-label
graphify export callflow-html --output docs/architecture-callflow.html
```

`--no-label` avoids model-based community naming where supported.

## Keeping graphs fresh

After edits:

```bash
graphify-update /path/to/project
```

Restart the MCP process after changing the graph. A running server keeps the
graph it received at startup.

For Git worktrees, keep a separate `graphify-out/` under each worktree. Do not
share one mutable graph between branches with substantially different source.

## Reference sidecars

Load only the sidecar needed for the task. Treat commands as version-sensitive
upstream references and verify support with the installed CLI.

- `references/query.md` — query, path, and explain behaviour;
- `references/update.md` — incremental refresh details;
- `references/exports.md` — export and database flows;
- `references/github-and-merge.md` — cloning and multi-repository merge flows;
- `references/add-watch.md` — URL ingestion and watch mode;
- `references/transcribe.md` — audio/video transcription;
- `references/extraction-spec.md` — graph output/schema expectations;
- `references/hooks.md` — agent hook behaviour.

When a sidecar conflicts with this skill's repository-scoping or MCP-selection
rules, follow this skill.
