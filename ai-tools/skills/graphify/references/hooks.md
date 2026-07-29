# graphify reference: hooks and always-on graph nudges

Load this when the user asks about Graphify hooks, Claude Code `PreToolUse` hooks, Zed equivalents, post-commit graph refreshes, or wiring Graphify into always-on project instructions.

## For git commit hook

Install a post-commit hook that auto-rebuilds the graph after every commit. No background process needed - triggers once per commit, works with any editor.

```bash
graphify hook install    # install
graphify hook uninstall  # remove
graphify hook status     # check
```

After every `git commit`, the hook detects which code files changed (via `git diff HEAD~1`), re-runs AST extraction on those files, and rebuilds `graph.json` and `GRAPH_REPORT.md`. Doc/image changes are ignored by the hook - run `/graphify --update` manually for those.

If a post-commit hook already exists, graphify appends to it rather than replacing it.

---

## Zed equivalent of Claude PreToolUse hooks

Claude Code supports `.claude/settings.json` `PreToolUse` hooks. Graphify uses
those hooks to intercept Bash search commands such as `grep`, `rg`, `ripgrep`,
`find`, `fd`, `ack`, and `ag`, plus Read/Glob source-file access, and remind
Claude to query `graphify-out/graph.json` first.

Zed skills do not support Claude-style `PreToolUse` hooks. Zed tool permissions
can allow, deny, or confirm tools, but they cannot inject Graphify-specific
context before a tool call. In Zed, represent this behavior as instructions:

- Before using broad search tools, check whether `graphify-out/graph.json`
  exists.
- If it exists, run a scoped Graphify query first.
- Use raw search/read tools only after Graphify identifies relevant files,
  symbols, or relationships.
- After code edits, run `graphify-update .` or the flake-backed update wrapper.

Preferred commands in this Nix/Zed setup:

```bash
nix run <nix-config-flake>#graphify-query -- \
  "question or symbol names" \
  --graph graphify-out/graph.json

nix run <nix-config-flake>#graphify-update -- .
```

## For native CLAUDE.md integration

This section is Claude-specific upstream reference material, not a Zed skill
mechanism. In Claude Code, running `graphify claude install` writes a
`## graphify` section to the local `CLAUDE.md` that instructs Claude to check the
graph before answering codebase questions and rebuild it after code changes.

```bash
graphify claude install
graphify claude uninstall  # remove the section
```
