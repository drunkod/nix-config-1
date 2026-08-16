# 5. Repo Harness operations, security, and troubleshooting

Use this guide to operate the shared `m1-min` Coding MCP service, recover from
common failures, and understand what it may and may not do.

## Authority map

| Layer | Owner | Durable state |
|---|---|---|
| Repo Harness CLI and protocol | `drunkod/repo-harness` | mutable Bun install under `~/.bun` |
| `m1-min` service and helpers | `drunkod/nix-config-1` | Nix/Home Manager and launchd |
| Repository adoption | each target repository | committed `.ai/harness` / task scaffolding |
| Repository access and OAuth | local user | `~/.repo-harness` — never commit |
| Quick Tunnel | helper-owned runtime | `~/.local/state/repo-harness-mcp-quick` |
| CodeGraph | Nix plus per-project index | project `.codegraph` state |
| Graphify | one graph per project/worktree | project `graphify-out` |

## Normal start/restart sequence

```bash
repo-harness --version
repo-harness-mcp-quick-restart
repo-harness-mcp-quick-test
repo-harness-mcp-quick-url
```

Use canonical `repo-harness-mcp-*` binaries in scripts and non-interactive
shells. The shorter `rh-mcp-*` names are interactive Zsh aliases.

`repo-harness-mcp-quick-restart`:

1. requires or restarts loopback MCP;
2. replaces the matching Quick Tunnel;
3. forces Cloudflare HTTP/2;
4. waits for hostname publication;
5. requires stable public probes;
6. refreshes the Coding MCP setup and access revision;
7. restarts MCP;
8. requires all live doctor layers to pass.

Do not continuously create new tunnels while diagnosing DNS publication. Keep
one tunnel alive long enough for its hostname to publish.

## Connect or reconnect ChatGPT

Print the current ephemeral MCP URL:

```bash
repo-harness-mcp-quick-url
```

In the ChatGPT developer-mode app:

1. replace the MCP URL with that exact value;
2. keep authentication set to OAuth;
3. click **Sign in with Repo Harness Coding**;
4. when the fresh `/authorize?...` page opens, do not submit the form;
5. copy the entire address from the browser address bar;
6. run:

```bash
repo-harness-mcp-chatgpt-auth
```

The helper clears the clipboard, validates the current public origin, PKCE
`S256`, the `chatgpt.com` callback, and the OAuth resource before submitting the
local passphrase.

Never paste the authorization URL, callback URL, passphrase, authorization code,
bearer token, cookies, or OAuth files into chat, issues, logs, or Git.

## Health commands

### Local service and OAuth discovery

```bash
repo-harness-mcp-health
```

### Full live doctor

```bash
repo-harness-mcp-doctor
```

Healthy result:

```text
status = mcp_ready
config_ready = true
local_ready = true
tunnel_ready = true
oauth_ready = true
mcp_ready = true
```

### End-to-end current endpoint

```bash
repo-harness-mcp-quick-test
```

A healthy server is not proof of ChatGPT invocation. Require a visible tool
call in a fresh conversation.

## Access operations

Grant only one canonical repository path at a time:

```bash
repo-harness mcp access set \
  --repo /absolute/path/to/repository \
  --mode read_only \
  --json
```

Enable source modification only when needed:

```bash
repo-harness mcp access set \
  --repo /absolute/path/to/repository \
  --mode read_write \
  --json
```

Downgrade to revoke write authority:

```bash
repo-harness mcp access set \
  --repo /absolute/path/to/repository \
  --mode read_only \
  --json
```

Access/profile changes advance the authorization revision. Restart the service,
refresh the ChatGPT app schema, and reauthorize. Old OAuth authorization failing
after a revision change is expected fail-closed behavior.

Repo Harness `0.15.0` does not expose a delete command for registry entries.
Do not hand-edit `registered-repos.json` or its authorization revision. Downgrade
unused entries to `read_only`; fix removal support upstream if deletion is
required.

## Security model

### Allowed

- read adopted repositories explicitly registered as `read_only` or
  `read_write`;
- modify source only in an adopted repository with explicit `read_write` access
  and Coding MCP enabled;
- open an isolated managed worktree from an approved base commit;
- read repository instructions and task-relevant files;
- apply bounded patches;
- run understood targeted commands;
- inspect status, diff, and validation output;
- clean a managed workspace locally only when it is safe and clean;
- expose the loopback service through authenticated HTTPS.

### Prohibited

- never bind Coding MCP to `0.0.0.0` or a LAN address;
- never grant `/`, `/Users/test`, `/tmp`, `~/src`, or another broad parent;
- never register a repository whose sensitive content is not excluded by
  `.ignore`;
- never treat `.gitignore`, hidden files, CodeGraph, or Graphify as security
  boundaries;
- never use `exec_command` to bypass `PATH_DENIED`, `PATH_IGNORED`, traversal,
  absolute-path, or symlink-escape failures;
- never commit or transmit `~/.repo-harness` or browser/tunnel credentials;
- never run imperative CodeGraph installers over Nix-managed configuration;
- never reuse one mutable Graphify graph across unrelated repositories or
  substantially different worktrees;
- never treat editing, commit, push, PR creation, and merge as one approval;
- never claim a tool was invoked based only on assistant prose;
- never claim full Strict workflow compliance after minimal adoption.

### Important shell caveat

`exec_command` runs with the authority of the local macOS user. The repository
grant controls Repo Harness repository operations; it is not an operating-system
sandbox for arbitrary shell commands. Keep command confirmations enabled and
review every command.

## Troubleshooting decision tree

### `repo-harness` is missing

```bash
rh-bootstrap
rehash
repo-harness --version
```

Do not run the upstream global installer over Nix-managed host files.

### `/health` returns `coding_disabled`

Check all three prerequisites:

1. the selected repository contains
   `.ai/harness/workflow-contract.json` in the current checkout/base;
2. the canonical repository path has `read_write` access;
3. user-scoped Coding MCP config is bound to the current authorization revision.

```bash
repo-harness status --json
repo-harness mcp access set --repo "$PWD" --mode read_write --json
repo-harness-mcp-quick-restart
```

Do not solve this by copying only the marker into an unrelated checkout.

### Minimal adoption needs an explicit boundary

For a deliberate MCP-only setup, preview and apply minimal mode with verification
explicitly disabled:

```bash
repo-harness init --mode minimal --no-codegraph --no-verify --dry-run
repo-harness init --mode minimal --no-codegraph --no-verify
repo-harness status --json
```

Minimal installs core MCP, task, and handoff scaffolding but omits the complete
standard policy, context, and architecture surfaces. Use standard adoption when
the repository needs the complete workflow contract. Never report minimal mode
as full Strict compliance.

### `open_workspace` cannot find the repository

- confirm the exact path is registered;
- confirm the access mode is `read_write`;
- use the opaque `repo_id`, not the path or basename;
- reauthorize after access changes;
- use a base commit containing adoption.

Resolve one exact ID locally if discovery omits it; do not expose the whole
registry. See guide 4.

### Workspace opened from the wrong state

Stop before editing. Compare returned `base_sha` with the approved SHA. Clean or
retain the incorrect workspace locally, then open a new one with an exact
`base_ref`.

### Workspace cleanup is refused

```bash
repo-harness mcp workspaces list --json
repo-harness mcp workspaces cleanup --workspace-id <id> --json
```

Cleanup rejects dirty or unmerged worktrees intentionally. Preserve, integrate,
or explicitly discard the work before retrying. There is no remote delete tool.

### Quick Tunnel changed URL

This is normal. Run:

```bash
repo-harness-mcp-quick-restart
repo-harness-mcp-quick-url
```

Then update the ChatGPT app, reauthorize, and repeat the read-only canary in a
fresh chat.

### Tunnel is green but ChatGPT calls no tools

If `repo-harness-mcp-quick-test` and the live doctor pass, classify this as a ChatGPT
surface/invocation problem first. Refresh the app schema, start a fresh chat,
and require an explicit single-tool prompt. Model prose is not evidence.

### OAuth loops or becomes invalid

Common causes:

- stale Quick Tunnel URL;
- stale authorization after a repository-access revision change;
- reused authorization URL;
- ChatGPT app schema/session not refreshed.

Generate one current tunnel, update the app URL, start a fresh sign-in, and run
`repo-harness-mcp-chatgpt-auth` with the newly copied authorization URL. Do not reuse old URLs.

### Architecture projection is unavailable or pending

First check whether the repository has `.ai/harness/policy.json`. Without it,
architecture projection is not configured. For a configured repository:

```bash
repo-harness architecture-projection status --json
repo-harness architecture-projection drain --json
```

In `0.15.0`, failed or unavailable projection remains pending for retry. Stop,
normal drain, and manual drain share the frozen changed set. Do not manually
acknowledge failed architecture work as clean.

### Setup, update, or doctor exits nonzero

```bash
repo-harness setup check --json
repo-harness update --check --json
repo-harness doctor --json
```

These read-only commands can exit nonzero when their structured result includes
blocked, warning, or failing checks. Inspect the JSON summary and individual
checks instead of assuming a parser or command failure.

### CodeGraph is missing or stale

CodeGraph is optional navigation metadata, not an MCP authorization gate. A code
mutation can succeed even when index refresh fails. Do not repeat the mutation.
Repair or refresh indexing separately using the Nix-managed installation.

Run the read-only Repo Harness preflight first:

```bash
repo-harness tools ensure codegraph \
  --check \
  --repo /absolute/path/to/repository \
  --json
```

Nix owns installation on this host, so do not execute imperative install or
upgrade advice. Initialize the canonical source checkout with:

```bash
codegraph init /absolute/path/to/repository
codegraph status /absolute/path/to/repository
```

This does not initialize future managed worktrees. In worktree mode, approve the
following exact command in each newly opened workspace before its first patch:

```text
codegraph init .
```

Then use `codegraph sync .` for later refreshes. `open_workspace` does not copy
or initialize `.codegraph/`.

### Graphify selects the wrong graph

Graphify must use one identified graph per process. Prefer:

```bash
graphify-mcp-run /absolute/project/graphify-out/graph.json
```

Never silently fall back to another repository graph. See the
[Graphify workflow](../../tools/graphify.md).

## Specialist references

Use these only after the numbered onboarding workflow is understood:

- [`m1-min` Coding MCP](../reference/m1-min-coding-mcp.md) — implementation and
  target-Mac validation details;
- [Quick Tunnel internals](../reference/quick-tunnel-internals.md) — helper
  behavior and manual fallback;
- [Browser Engine and GitHub Create/Review](../reference/browser-engine-github-create-review.md)
  — separate Browser planning/GitHub-app workflow;
- [Browser Create smoke test, 2026-08-03](../history/browser-create-smoke-test-2026-08-03.md)
  — historical bounded test evidence.

The Browser Engine/GitHub app workflow is not the same as Coding MCP. Use Coding
MCP for local managed-workspace edits. Use Browser Engine only when you
explicitly want its planning or GitHub-app Create/Review workflow.
