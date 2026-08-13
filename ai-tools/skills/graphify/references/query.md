# Graphify reference: query and traversal

Version scope: Graphify revision `0b2bd938c4a48e91d27f0ba09b96409e0a36c78a`. Verify flags with the root `graphify --help`. Always identify one graph explicitly; do not rely on the CLI's relative default.

```bash
GRAPH=/absolute/project/graphify-out/graph.json
```

Use the installed query wrapper for focused questions:

```bash
graphify-query "what calls RuntimeBridge" --graph "$GRAPH"
graphify-query "how does A reach B" --dfs --budget 3000 --graph "$GRAPH"
graphify-query "question" --context call --graph "$GRAPH"
```

Use concrete labels, symbols, files, or modules. If matching is weak, inspect `god-nodes` or use a narrower literal term; do not generate private vocabulary files or fabricate query expansion.

Current direct traversal commands include:

```bash
graphify path "NODE_A" "NODE_B" --graph "$GRAPH"
graphify explain "NODE" --graph "$GRAPH"
graphify affected "NODE" --depth 2 --graph "$GRAPH"
graphify god-nodes --top 10 --graph "$GRAPH"
graphify tree --graph "$GRAPH" --output /absolute/project/graphify-out/GRAPH_TREE.html
graphify reflect --graph "$GRAPH"
```

`reflect` consumes saved work-memory outcomes; it is not required for ordinary querying. Saving query results is optional and should not be presented as an automatic pipeline.

If the CLI lacks enough detail, prefer explicit MCP over ad hoc Python traversal:

```bash
graphify-mcp-run "$GRAPH"
```

Answer from graph evidence, then verify important implementation claims in source. Never invoke `graphify-out/.graphify_python`.
