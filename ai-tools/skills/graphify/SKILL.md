---
name: graphify
description: Use when the user wants to map, index, understand, or query a local codebase/folder or existing graphify-out knowledge graph — including architecture questions, file relationships, project content, "what calls X", "what depends on Y", "trace the path from A to B", query/path/explain workflows, graph exports, graph refreshes after edits, or Graphify MCP/direct traversal. Runs fully offline for code-only corpora via tree-sitter; docs/PDFs/images/video may use semantic extraction only when explicitly requested.
---

# Graphify for Zed (local, offline-first graph)

Build, refresh, and query a knowledge graph from a local folder in Zed. For
code-only corpora, Graphify uses deterministic local tree-sitter extraction: no
API key, no LLM, and nothing leaves the machine. Docs/PDFs/images/video can
trigger semantic model APIs or transcription, so keep the corpus code-only unless
the user explicitly requests multimodal/semantic extraction.

This Zed skill is wired to the user's `nix-config` flake integration, not to a
Claude slash command or standalone global `graphify` CLI. Prefer the flake apps
below.

## Setup assumptions

The user's system configuration exposes flake-backed Graphify commands from
their `nix-config` checkout. Determine the flake path once per session:

1. Prefer a user-provided path if mentioned.
2. Otherwise check common locations such as `~/nix-config` or `~/.setup`.
3. If still unclear, ask for the path to the `nix-config` flake.

Call that path `<nix-config-flake>`. Use:

- `nix run <nix-config-flake>#graphify-extract -- <project>`
- `nix run <nix-config-flake>#graphify-update -- <project>`
- `nix run <nix-config-flake>#graphify-query -- <question> --graph <graph.json>`
- `nix run <nix-config-flake>#graphify-mcp -- <graph.json>`
- `nix develop <nix-config-flake>#graphify`

Interactive shell aliases may exist (`graphify-extract`, `graphify-update`,
`graphify-query`, `graphify-mcp`, `graphify-shell`), but prefer explicit
`nix run` / `nix develop` commands.

## Core workflow

Fast path: if `graphify-out/graph.json` already exists and the user asks a
natural-language codebase question, query the existing graph first. Do not
rebuild unless the user asks for a fresh extraction/update or the graph is stale.

Use this offline pattern:

```text
offline extract/update
→ graph.json / GRAPH_REPORT.md
→ scoped keyword/entity query
→ MCP/direct graph traversal for exact edges
→ raw source read only for verification
```

1. Confirm the target project folder and work from its root.
2. Build or refresh the code-only graph:
   - First build: `nix run <nix-config-flake>#graphify-extract -- .`
   - After edits: `nix run <nix-config-flake>#graphify-update -- .`
3. Verify the run stayed offline/code-only. Healthy output has `0 docs, 0 papers, 0 images`.
   If not, fix `.graphifyignore`; do not add an LLM/API key unless requested.
4. Use outputs in `<target>/graphify-out/`:
   - `graph.json` — full graph; source of truth for exact traversal
   - `manifest.json` — file inventory
   - `GRAPH_REPORT.md` — architecture highlights, if generated
   - `graph.html` / callflow HTML — visual exploration, if exported
5. Consult the graph before raw `Glob`/`Grep`/file reads. Use raw source only to
   verify or inspect implementation details after graph exploration.

## Reference sidecars

Load these files only when the task needs the extra detail. These sidecars are
generated from Graphify's upstream Claude skill, so adapt them to this Zed/Nix
setup:

- Prefer the `graphify-*` wrappers or `nix run <nix-config-flake>#graphify-*`
  commands from this `SKILL.md` over `/graphify` slash-command examples.
- Treat commands in sidecars as version-sensitive upstream references. Verify
  support with `graphify --help` or wrapper help before running export/import
  flows that are not listed by the installed CLI.
- Some snippets assume the Claude pipeline created
  `graphify-out/.graphify_python`. In this Zed/Nix setup, prefer wrappers or run
  commands inside `nix develop <nix-config-flake>#graphify` unless that file
  exists.

Sidecars:

- `references/query.md` — `graphify query`, `path`, and `explain` behavior and examples.
- `references/update.md` — incremental refresh, cache handling, and update edge cases.
- `references/exports.md` — HTML/SVG/GraphML/Neo4j/FalkorDB/wiki/export flows.
- `references/github-and-merge.md` — GitHub repo cloning and multi-repository merge flows.
- `references/add-watch.md` — URL ingestion and watch mode.
- `references/transcribe.md` — audio/video transcription before graph extraction.
- `references/extraction-spec.md` — extraction output/schema expectations.
- `references/hooks.md` — hook behavior for nudging agents toward existing graphs.

## Query policy: keyword/entity mode

`graphify-query` is allowed and preferred for scoped graph questions. Do not use
it as a broad LLM-like prompt engine.

Use `graphify-query` only after identifying concrete graph terms, such as file
names, class names, function names, package names, crate names, directories, or
concepts already present in `graphify-out/graph.json` or `GRAPH_REPORT.md`.

Good examples:

```bash
nix run <nix-config-flake>#graphify-query -- \
  "what calls RuntimeBridge" \
  --graph ./graphify-out/graph.json

nix run <nix-config-flake>#graphify-query -- \
  "MainActivity AppGraph RuntimeBridge ScreenCaptureCoordinator" \
  --graph ./graphify-out/graph.json

nix run <nix-config-flake>#graphify-query -- \
  "what connects MainActivity to nativeProcessFrame" \
  --graph ./graphify-out/graph.json
```

Avoid broad prompt-like queries:

```bash
nix run <nix-config-flake>#graphify-query -- \
  "Summarize the whole architecture and create Mermaid" \
  --graph ./graphify-out/graph.json
```

## Broad architecture workflow

For broad architecture questions, do not start with a broad natural-language
`graphify-query`. Instead:

1. Read `graphify-out/GRAPH_REPORT.md` if present.
2. Inspect `graphify-out/graph.json` locally for top modules/directories,
   communities, high-degree nodes, and representative labels.
3. Run targeted `graphify-query`, `path`, `explain`, or MCP traversal on
   discovered concrete names.
4. Generate the final architecture summary or Mermaid diagram from those graph
   results, then verify important claims against source files.

A quick local graph inspection snippet:

```bash
python3 - <<'PY'
import json
from collections import Counter

g = json.load(open("graphify-out/graph.json"))
edges = g.get("edges") or g.get("links") or []
print("nodes", len(g.get("nodes", [])))
print("edges", len(edges))

roots = Counter()
labels = []
for n in g.get("nodes", []):
    src = n.get("source_file") or ""
    label = n.get("label") or n.get("id") or ""
    if src:
        roots[src.split("/")[0]] += 1
    if label:
        labels.append(label)

print("\nTop roots:")
for k, v in roots.most_common(20):
    print(v, k)

print("\nSample labels:")
for x in labels[:80]:
    print(x)
PY
```

## MCP and exact traversal

The user's configuration already defines a `graphify` MCP server. It will:

- use `GRAPHIFY_GRAPH_PATH` if set, or
- search upward from the current directory for `graphify-out/graph.json`.

Use MCP/direct traversal when exact edges matter. Prefer structured graph tools
such as `query_graph`, `get_node`, `get_neighbors`, and `shortest_path` over
natural-language query for precise dependency/call/path questions.

## Reports and diagrams

If `GRAPH_REPORT.md` is absent and a human-readable architecture view is needed,
prefer an offline report/export path. If the flake exposes a wrapper, use it; if
working inside the Graphify dev shell, use Graphify's CLI directly, for example:

```bash
graphify cluster-only . --no-label
graphify export callflow-html --output docs/architecture-callflow.html
```

`--no-label` avoids LLM community naming. `callflow-html` is the preferred route
for readable architecture/call-flow Mermaid diagrams when available.

## Keeping graphs fresh

After code edits, refresh with:

```bash
nix run <nix-config-flake>#graphify-update -- .
```

For team workflows, it is usually reasonable to commit stable graph artifacts:

- `graphify-out/graph.json`
- `graphify-out/manifest.json`
- `graphify-out/GRAPH_REPORT.md`
- `graphify-out/graph.html` or callflow HTML, if useful

Usually ignore local/transient artifacts such as:

- `graphify-out/cost.json`
- `graphify-out/cache/`

## Notes

- Code-only extraction is local and deterministic; no tokens spent, nothing leaves the machine.
- Non-code files (docs/PDFs/images/video) may trigger semantic extraction or transcription through model APIs/tools.
- Keep `.graphifyignore` strict enough to preserve `0 docs, 0 papers, 0 images` for offline privacy when the user wants code-only analysis.
- Do not tell the user to run `pip install graphify`; this integrated setup uses the user's flake apps.
- Do not include Claude-specific `.claude/CLAUDE.md`, `.claude/settings.json`, or `.graphify_version` files in the Zed skill. The Zed skill package is `SKILL.md` plus optional `references/` sidecars.
