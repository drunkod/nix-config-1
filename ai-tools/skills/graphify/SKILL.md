---
name: graphify
description: Use when the user wants to map, index, understand, or query a local codebase/folder — building a knowledge graph of files, classes, functions, and their relationships (imports, calls, inherits). Runs fully offline via tree-sitter (no API key, no LLM). Prefer this over raw Glob/Grep for "how is this project structured", "what calls X", "what depends on Y", "trace the path from A to B".
---

# Graphify (local, offline, no-LLM)

Build and query a code knowledge graph from a local folder using deterministic
tree-sitter extraction. No API key, no LLM, no network — safe for private code.

This skill is wired to the user's `nix-config` flake integration, not to a
standalone globally installed `graphify` CLI. Prefer the flake apps below.

## When to use

- "map / index this project", "build a knowledge graph", "analyze the architecture"
- "what calls `X`", "what depends on `Y`", "how are these modules connected"
- "trace the path from `A` to `B`", "explain `SomeClass`"
- Before falling back to raw `Glob`/`Grep`, consult the graph first.

## Setup assumptions

The user's system configuration exposes flake-backed Graphify commands from
their `nix-config` checkout. First determine the flake path once for the
session:

1. Prefer a user-provided path if they mention one.
2. Otherwise check common locations such as `~/nix-config` or `~/.setup`.
3. If still unclear, ask the user for the path to their `nix-config` flake.

Call that path `<nix-config-flake>`. Then use:

- `nix run <nix-config-flake>#graphify-extract -- <project>`
- `nix run <nix-config-flake>#graphify-update -- <project>`
- `nix run <nix-config-flake>#graphify-query -- <question> [--graph <path>]`
- `nix run <nix-config-flake>#graphify-mcp -- <graph.json>`
- `nix develop <nix-config-flake>#graphify`

If the user is in an interactive shell with aliases loaded, the shorter aliases
`graphify-extract`, `graphify-update`, `graphify-query`, `graphify-mcp`, and
`graphify-shell` may also exist — but do not rely on shell aliases when you can
run the full `nix run` / `nix develop` commands directly.

## Workflow

1. Ask the user to grant access to / confirm the target project folder.
2. Work from the target project root.
3. Build or refresh the graph, **code-only and offline**:
   - First build:
     `nix run <nix-config-flake>#graphify-extract -- .`
   - After edits:
     `nix run <nix-config-flake>#graphify-update -- .`
   - These wrappers already keep Graphify on the offline/no-LLM path.
   - Keep docs/PDFs/images out of the corpus (a `.graphifyignore` helps) so
     Graphify stays on deterministic tree-sitter extraction.
4. Primary output lives in `<target>/graphify-out/`:
   - `graph.json`     — the knowledge graph (nodes + edges); the source of truth
   - `manifest.json`  — file inventory
5. Query the graph instead of grepping raw files:
   - `nix run <nix-config-flake>#graphify-query -- "your question" --graph ./graphify-out/graph.json`
   - If you need exact symbol traversal and the CLI question interface is not
     enough, use the configured `graphify` MCP server against the same graph.
6. Only fall back to raw file reads after consulting the graph.

## MCP usage in this system

The user's configuration already defines a `graphify` MCP server. It will:

- use `GRAPHIFY_GRAPH_PATH` if set, or
- search upward from the current directory for `graphify-out/graph.json`

Use MCP when you want structured graph navigation (`query_graph`, `get_node`,
`get_neighbors`, `shortest_path`) instead of text queries.

## Notes

- Pure tree-sitter extraction → deterministic, no tokens spent, nothing leaves the machine.
- The semantic LLM pass only triggers for non-code files (docs/PDFs/images); a
  code-only corpus skips it entirely.
- Do not tell the user to run `pip install graphify` or to look for
  `mcp/graphify.mcp.json` next to this skill; this integrated setup does not use
  that layout.
