# Graphify

The canonical, tested Graphify guide for the default `m1-min` profile is:

```text
docs/graphify-new-repository.md
```

Use that document for:

- installation and architecture;
- initial code-only extraction;
- incremental updates;
- explicit CLI queries;
- automatic, explicit, and saved MCP modes;
- Git branches and worktrees;
- Graphify/CodeGraph coexistence;
- Nix-free sandbox use;
- allowed and prohibited operations;
- current local validation results.

The implementation sources are:

```text
modules/programs/graphify.nix
modules/programs/mcp.nix
nix/graphify.nix
scripts/graphify-sandbox.sh
```

The default safety invariant is:

> One Graphify query or MCP process must use one identified graph from one
> repository or worktree.

Do not duplicate operational instructions in this file. Update
`docs/graphify-new-repository.md` when the pinned Graphify revision or wrapper
behavior changes.
