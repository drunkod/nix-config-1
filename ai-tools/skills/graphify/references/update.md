# Graphify reference: update and clustering

Version scope: Graphify revision `0b2bd938c4a48e91d27f0ba09b96409e0a36c78a`. Verify flags with the root `graphify --help` before use.

## Initial extraction

If `<project>/graphify-out/graph.json` does not exist, create it with the extraction wrapper:

```bash
graphify-extract /absolute/path/to/project --code-only
```

`--code-only` is supported by **extract** and provides deterministic local AST extraction.

## Code update

If the graph already exists and source code changed:

```bash
graphify-update /absolute/path/to/project
```

The wrapper preserves `graph.json` and `manifest.json` and invokes the current code-update path. `--code-only` is **not supported on update**; do not pass it. Current update options include:

```bash
graphify-update /absolute/path/to/project --force
graphify-update /absolute/path/to/project --no-cluster
```

Use `--force` only when the user intends to accept a rebuild with fewer nodes, such as after a large deletion or refactor. The repository wrapper already adds `--no-cluster`, so passing it explicitly is normally unnecessary.

Do not delete graph state before an incremental update. Do not reproduce detection, manifest, merge, pruning, or diff internals manually. Never invoke `graphify-out/.graphify_python`.

## Recluster an existing graph

Clustering is separate from the update wrapper:

```bash
graphify cluster-only /absolute/path/to/project --no-label
```

`--no-label` keeps deterministic placeholder names and avoids model-based community naming. Naming communities is semantic and opt-in; it may require network access and a provider API key. For other cluster flags, consult the installed root help.
