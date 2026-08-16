# Repo Harness safety rules

Read this once before using the tutorials. Other guides link here instead of
repeating these rules.

## Repository access

- Review `.ignore` before `repo-harness init`; initialization registers the
  repository `read_only`.
- Grant only one canonical repository path. Use `read_write` only for editing.
- `.gitignore`, hidden files, CodeGraph, and Graphify are not authorization
  boundaries.
- Do not bypass a denied path with `exec_command`, traversal, absolute paths,
  copied files, or symlinks.

## Credentials and runtime state

Do not put OAuth URLs, tokens, cookies, passphrases, private keys, Cloudflare
credentials, browser profiles, or `~/.repo-harness` state in chat, logs, Git, or
context packets.

Keep generated local state untracked, including:

```text
.ai/harness/mcp/
.ai/context-packets/
.codegraph/
graphify-out/
```

## Context sharing

- Local `gitingest .` processes the checkout locally, but its output contains
  source and must be reviewed before sharing.
- Remote URL ingestion and `gitingest.com` involve external processing. Use them
  for private code only when repository policy permits it.
- Attach only task-relevant, reviewed files. A normal ChatGPT attachment is not
  automatically available to Browser Engine or Coding MCP.

## Managed workspaces and commands

- Prefer managed worktree mode from an exact adopted SHA.
- Shell commands run with local-user authority; a repository grant is not an OS
  sandbox.
- Each worktree has separate `.codegraph/` and `graphify-out/` state. Never copy
  or symlink indexes between worktrees.
- If a patch succeeds but index refresh fails, do not repeat the patch. Repair
  the index separately.
- Do not force-clean a dirty managed workspace. Inspect and preserve or discard
  its work deliberately.

## Git and remote writes

Treat edit, commit, push, PR creation, review comments, CI reruns, readiness,
and merge as separate actions. Review changed paths, diff, and validation before
each write boundary.

## More detail

For access operations, OAuth recovery, tunnel failures, cleanup, and diagnostic
decision trees, see
[operations, security, and troubleshooting](guides/05-operations-security-troubleshooting.md).
