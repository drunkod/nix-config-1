# Graphify reference: clone and merge graphs

Version scope: Graphify revision `0b2bd938c4a48e91d27f0ba09b96409e0a36c78a`. Verify clone and merge syntax with the root `graphify --help` before use.

## Clone (networked, opt-in)

```bash
graphify clone https://github.com/<owner>/<repo> --branch <branch> --out <directory>
```

Cloning uses the network. Prefer an explicit `--out` path so repository identity is visible; do not assume or depend on a global clone cache.

Build each repository independently, using code-only extraction unless semantic ingestion was explicitly requested:

```bash
graphify-extract /absolute/repo-a --code-only
graphify-extract /absolute/repo-b --code-only
```

## Merge explicit graphs

```bash
graphify merge-graphs \
  /absolute/repo-a/graphify-out/graph.json \
  /absolute/repo-b/graphify-out/graph.json \
  --out /absolute/output/cross-repo-graph.json
```

The inputs must already exist. Keep each source repository's graph separate and treat the merged file as a distinct graph. Query it explicitly:

```bash
graphify-query "question with concrete symbols" \
  --graph /absolute/output/cross-repo-graph.json
```

For local monorepo components, use the same pattern: extract each component to its own `graphify-out/`, then merge the explicit graph paths. Never invoke `graphify-out/.graphify_python` or fabricate a multi-agent extraction pipeline.
