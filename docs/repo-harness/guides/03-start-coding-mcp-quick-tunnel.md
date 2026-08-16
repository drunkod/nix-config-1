# 3. Start Repo Harness Coding MCP and Quick Tunnel

Use this guide after repository adoption and optional CodeGraph initialization.
It starts or verifies the `m1-min` Coding MCP service, exposes it through an
ephemeral authenticated HTTPS endpoint, and connects ChatGPT. Shared rules:
[`Repo Harness safety`](../safety.md).

## Command names

The short `rh-mcp-*` names are interactive Zsh aliases. They are unavailable in
non-interactive `/bin/sh` processes. Tutorials and scripts should use the
canonical binaries:

| Canonical command | Interactive alias |
|---|---|
| `repo-harness-mcp-quick-restart` | `rh-mcp-quick-restart` |
| `repo-harness-mcp-quick-test` | `rh-mcp-quick-test` |
| `repo-harness-mcp-quick-url` | `rh-mcp-quick-url` |
| `repo-harness-mcp-chatgpt-auth` | `rh-mcp-auth` |
| `repo-harness-mcp-health` | `rh-mcp-health` |
| `repo-harness-mcp-doctor` | `rh-mcp-doctor` |

Check availability:

```bash
command -v repo-harness-mcp-quick-restart
command -v repo-harness-mcp-quick-test
command -v repo-harness-mcp-quick-url
command -v repo-harness-mcp-chatgpt-auth
```

## Step 1: verify repository access

```bash
cd /absolute/path/to/repository
repo-harness status --json
```

The repository must be adopted. For Coding MCP, set only its canonical path to
`read_write` after the adoption commit is reviewed and durable:

```bash
repo-harness mcp access set \
  --repo "$PWD" \
  --mode read_write \
  --json
```

Access changes advance the authorization revision and require MCP setup refresh
plus fresh ChatGPT OAuth.

## Step 2: choose one endpoint path

Choose exactly one of the following alternatives.

### Option A: start or replace the Quick Tunnel

Use this for initial setup, a dead endpoint, or an intentionally replaced
endpoint:

```bash
repo-harness-mcp-quick-restart
```

The helper:

1. requires or restarts loopback MCP on `127.0.0.1:8765`;
2. starts Cloudflare Tunnel with HTTP/2;
3. waits for hostname publication;
4. requires stable public probes;
5. bootstraps user-scoped Coding MCP against the new `/mcp` URL;
6. restarts MCP;
7. requires the live doctor to reach `mcp_ready`.

Quick Tunnel URLs are ephemeral. Do not put one in committed documentation.

### Option B: reuse a healthy existing endpoint after access changes

If the current Quick Tunnel is healthy and only repository access changed, do
not run Option A. Reuse the endpoint:

```bash
MCP_ENDPOINT="$(repo-harness-mcp-quick-url)"

case "$MCP_ENDPOINT" in
  https://*/mcp) ;;
  *) echo "STOP: invalid endpoint" >&2; unset MCP_ENDPOINT; exit 1 ;;
esac

repo-harness-mcp-bootstrap \
  --repo /absolute/path/to/repository \
  --endpoint "$MCP_ENDPOINT"

unset MCP_ENDPOINT
repo-harness-mcp-restart
```


## Step 3: verify all live layers

```bash
repo-harness-mcp-health
repo-harness-mcp-quick-test
repo-harness-mcp-doctor
```

Require:

```text
config_ready  true
local_ready   true
tunnel_ready  true
oauth_ready   true
mcp_ready     true
```

The in-ChatGPT `harness_doctor` tool may report `ready_local`; that is not the
same as this operator-side five-layer live doctor.

## Step 4: configure and authorize ChatGPT

Obtain the URL privately:

```bash
repo-harness-mcp-quick-url
```

In the ChatGPT developer-mode app:

1. set that exact URL;
2. select OAuth;
3. click **Sign in with Repo Harness Coding**;
4. copy the fresh `/authorize?...` URL from the browser address bar without
   submitting the form;
5. run:

```bash
repo-harness-mcp-chatgpt-auth
```

Expected safe result:

```text
Authorization HTTP status: 302
OAuth accepted; opening ChatGPT callback
```


## Step 5: run visible invocation canaries

Start a fresh ChatGPT conversation after authorization or schema changes.
Require a visible tool event for each call.

First:

```text
Use Repo Harness Coding and call harness_status only.
Do not modify anything or run shell commands.
```

`harness_status` reports the service's configured bootstrap repository, which may
be `~/nix-config`; it does not select the repository for a future workspace.

Then:

```text
Use Repo Harness Coding and call harness_doctor only.
Do not modify anything or run shell commands.
```

Then discover the target repository:

```text
Use Repo Harness Coding and call discover_harness_repos only.
Find only /absolute/path/to/repository.
Do not read files, open a workspace, modify anything, or run shell commands.
```

Discovery may:

- omit both `repo_id` and `accessMode`;
- include `scannedRoots` metadata naming another configured root.

Resolve one exact opaque ID locally when omitted; never expose the whole registry:

```bash
REPO_ROOT="$(cd /absolute/path/to/repository && pwd -P)"

jq -r \
  --arg path "$REPO_ROOT" \
  '.repos[] | select(.path == $path and .accessMode == "read_write") | .id' \
  "$HOME/.repo-harness/registered-repos.json"
```

## Step 6: open a managed workspace

Use the exact repository ID and a commit containing adoption:

```json
{
  "repo_id": "repo_...",
  "mode": "worktree",
  "base_ref": "<exact-adopted-commit-sha>"
}
```

Require:

```text
mode          worktree
managed       true
base_sha      exact approved SHA
dirty_source  false
```

The local worktree path is intentionally opaque.

## Step 7: initialize CodeGraph inside the workspace

Before the first `apply_patch`, approve one exact `exec_command` in that
workspace:

```text
codegraph init .
```

This is required because source-checkout indexes are not copied into managed
worktrees. See guide 2. Verify with `codegraph status . --json` if needed.

## Step 8: run read and containment canaries

Read one harmless adopted file, such as `docs/spec.md`, then attempt:

```text
../outside
```

The traversal read must fail with a containment error such as:

```text
INVALID_RELATIVE_PATH
```

Do not use another tool or shell command to bypass the denial.

## Completion checklist

```text
[ ] canonical helpers resolve
[ ] exact target repository is adopted and read_write
[ ] access revision is bound to current MCP config
[ ] all five operator doctor layers are green
[ ] ChatGPT OAuth completed with a fresh authorization URL
[ ] visible status/doctor/discovery calls occurred
[ ] exact repo_id and adopted base SHA selected
[ ] managed worktree opened with dirty_source=false
[ ] CodeGraph initialized inside that managed workspace
[ ] harmless read succeeded
[ ] ../outside was denied without fallback bypass
```

Continue with [guide 4: daily Coding workflow](04-daily-coding-workflow.md).
For implementation details, see [Quick Tunnel internals](../reference/quick-tunnel-internals.md).
