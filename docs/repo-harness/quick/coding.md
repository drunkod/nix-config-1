# Repo Harness Coding MCP: short tutorial

Use Coding when ChatGPT must edit an adopted repository through an isolated
managed worktree. Shared rules: [`Repo Harness safety`](../safety.md).

## 1. Adopt and commit

```bash
cd /absolute/path/to/repository
repo-harness init --mode minimal --no-codegraph --no-verify --dry-run
repo-harness init --mode minimal --no-codegraph --no-verify
repo-harness status --json
```

Review and commit adoption. The exact `open_workspace` base SHA must contain the
adoption files.

## 2. Initialize source CodeGraph

```bash
repo-harness tools ensure codegraph --check --repo "$PWD" --json
codegraph init "$PWD"
codegraph status "$PWD"
```

Do not run CodeGraph's installer; Nix owns the CLI/MCP configuration.

## 3. Grant one exact repository

```bash
repo-harness mcp access set \
  --repo "$PWD" \
  --mode read_write \
  --json
```

Record the opaque `repo_id` and authorization revision. Never grant a broad
parent directory.

## 4. Start or refresh Coding MCP

First setup when `~/.repo-harness/mcp.local.json` does not exist requires a
syntactically valid placeholder endpoint so the local Coding service can start:

```bash
repo-harness-mcp-bootstrap \
  --repo "$PWD" \
  --endpoint https://mcp.invalid/mcp
repo-harness-mcp-restart
repo-harness-mcp-quick-restart
```

The Quick Tunnel helper replaces the placeholder with the generated real
endpoint and runs the full doctor. Do not configure ChatGPT with `mcp.invalid`.

Existing config with a dead/expired endpoint:

```bash
repo-harness-mcp-quick-restart
```

Healthy existing endpoint after only an access change:

```bash
ENDPOINT="$(repo-harness-mcp-quick-url)"
repo-harness-mcp-bootstrap --repo "$PWD" --endpoint "$ENDPOINT"
unset ENDPOINT
repo-harness-mcp-restart
```

Verify:

```bash
repo-harness-mcp-quick-test
```

## 5. Authorize ChatGPT

Update the ChatGPT developer-mode app to the current URL when needed, select
OAuth, copy the fresh `/authorize?...` URL, then run:

```bash
repo-harness-mcp-chatgpt-auth
```


## 6. Visible canaries

In a fresh ChatGPT conversation:

```text
Call harness_status only.
Call harness_doctor only.
Call discover_harness_repos only for the exact target repository.
```

Require visible tool events. Discovery may omit `repo_id` and `accessMode`; use
the one exact locally resolved ID, not the complete registry.

## 7. Open an isolated workspace

```json
{
  "repo_id": "repo_...",
  "mode": "worktree",
  "base_ref": "<exact-adopted-sha>"
}
```

Require `managed:true`, exact `base_sha`, and `dirty_source:false`.

## 8. Initialize CodeGraph in that workspace

Before the first patch, approve exactly:

```text
codegraph init .
```

The source checkout's ignored `.codegraph/` is not copied into managed
worktrees. If a mutation succeeds but index refresh fails, do not repeat the
mutation; initialize/sync the index separately.

## 9. Safety canaries

1. read one harmless file;
2. attempt `../outside` and require `INVALID_RELATIVE_PATH`;
3. create one temporary file with `apply_patch`;
4. verify it;
5. delete it with an exact SHA precondition;
6. require CodeGraph index state `ready`.

## 10. Work and clean up

Keep edits bounded. Commit, push, PR creation, and merge are separate approvals.

Repo Harness can create untracked evidence under `.ai/harness/mcp/` inside the
managed worktree. Cleanup is conservative; follow the shared safety guide.

```bash
repo-harness mcp workspaces cleanup --workspace-id <id> --json
```

Downgrade access when finished:

```bash
repo-harness mcp access set --repo "$PWD" --mode read_only --json
```
