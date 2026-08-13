# Code-intelligence tools

## Choose one

| Need | Tool | Guide |
|---|---|---|
| Focused source, symbols, call paths, and affected tests | CodeGraph | [CodeGraph workflow](codegraph.md) |
| Explicit graph traversal, dependency paths, impact, and exports | Graphify | [Graphify workflow](graphify.md) |

Both tools are Nix-managed and keep separate per-repository or per-worktree
state:

```text
.codegraph/
graphify-out/
```

Initialize only the tool needed for a task. When both are useful, follow the
shared preflight in the [developer recipe index](../developer-recipes/README.md#shared-index-preflight).

Back to the [documentation index](../README.md).
