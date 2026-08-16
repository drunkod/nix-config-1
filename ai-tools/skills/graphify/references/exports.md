# Graphify reference: exports and MCP

Version scope: Graphify revision `0b2bd938c4a48e91d27f0ba09b96409e0a36c78a`. Export support is version-sensitive: verify it in the root `graphify --help`. At this revision, `graphify export --help` prints only generic help and is not an authoritative capability list.

## Supported export

The root help advertises only the call-flow HTML export:

```bash
graphify export callflow-html --output /absolute/path/to/callflow.html
```

Run it from the project whose `graphify-out/graph.json` should be exported. Confirm the graph belongs to that project first. Do not recommend wiki, Neo4j, FalkorDB, SVG, or GraphML exports unless a future root help explicitly advertises them.

For a hierarchy view, the current CLI also supports:

```bash
graphify tree \
  --graph /absolute/project/graphify-out/graph.json \
  --output /absolute/project/graphify-out/GRAPH_TREE.html
```

## Explicit MCP

MCP is not an export. Prefer the repository wrapper and identify one graph explicitly:

```bash
graphify-mcp-run /absolute/project/graphify-out/graph.json
```

Equivalent flake app when installed commands are unavailable:

```bash
nix run <nix-config-flake>#graphify-mcp-run -- \
  /absolute/project/graphify-out/graph.json
```

MCP requires the `mcp` extra. Never start it through `python -m`, never invoke `graphify-out/.graphify_python`, and never rely on an unrelated default graph.
