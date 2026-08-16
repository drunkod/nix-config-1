# Graphify reference: hooks

Version scope: Graphify revision `0b2bd938c4a48e91d27f0ba09b96409e0a36c78a`. Verify hook commands with the root `graphify --help` before changing repository hooks.

## Git hooks

Run these from the intended Git repository:

```bash
graphify hook status
graphify hook install
graphify hook uninstall
```

Inspect existing hooks before installation and check status afterward. Hook implementation details are version-sensitive; do not promise exact changed-file, merge-driver, or report behavior beyond what the installed command reports.

## Editor and agent integrations

The current CLI also advertises platform-specific install/uninstall commands, but those modify instruction or hook files and should run only when the user requests that integration. Zed does not provide Claude Code `PreToolUse` hooks; represent graph-first behavior in agent instructions instead:

1. Identify the exact project graph.
2. Query it explicitly:

   ```bash
   graphify-query "question or symbol names" \
     --graph /absolute/project/graphify-out/graph.json
   ```

3. Verify important results in source.
4. After code edits, refresh with:

   ```bash
   graphify-update /absolute/project
   ```

`graphify-update` does **not** accept `--code-only`. Never invoke `graphify-out/.graphify_python`.
