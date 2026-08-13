# Repo Harness MCP coding profile on `m1-min`

> Specialist reference. Start with [`repo-harness-01-onboard-repository.md`](repo-harness-01-onboard-repository.md), then [`repo-harness-02-daily-workflow.md`](repo-harness-02-daily-workflow.md). Use this document for implementation and target-Mac validation details.

This runbook configures the Repo Harness `coding` profile on the Apple Silicon
`m1-min` host with a loopback MCP server and a Cloudflare public endpoint.

The **default path is now Cloudflare Quick Tunnel**:

```text
ChatGPT
  -> OAuth HTTPS /mcp
    -> https://<random>.trycloudflare.com/mcp
      -> cloudflared --protocol http2
        -> http://127.0.0.1:8765
          -> Repo Harness coding profile
            -> ~/nix-config
```

A Cloudflare account, custom domain, tunnel UUID, DNS route, and tunnel
credential JSON are **not required** for the normal `m1-min` test workflow.

The named-tunnel module remains imported but disabled. Enable it deliberately
only when you want a stable custom hostname.

## Source authority

The implementation follows `drunkod/repo-harness` branch
`agent/chatgpt-github-create-mvp`, including the ChatGPT MCP coding tutorial and
the Quick Tunnel testing workflow.

## What Nix owns

For `m1-min`, Home Manager owns:

- the existing Repo Harness launcher;
- `cloudflared`;
- the loopback Repo Harness MCP launchd agent;
- the Quick Tunnel helpers;
- the optional named-tunnel module, disabled by default;
- restart, health, doctor, bootstrap, URL, and OAuth helper commands;
- private runtime directories and logs;
- static assertions that keep the coding server on loopback and runtime state
  outside `/nix/store`.

The default Quick Tunnel path does not require Nix to log into Cloudflare or
manage DNS.

## Default versus optional public path

| Mode | Default | Public URL | Cloudflare account/domain required |
|---|---:|---|---:|
| Quick Tunnel | yes | `https://<random>.trycloudflare.com/mcp` | no |
| Named tunnel | no | `https://mcp.example.com/mcp` | yes |

Quick Tunnel hostnames are ephemeral. Replacing the tunnel produces a new URL,
so the ChatGPT app must be updated and authorized again.

A named tunnel is optional and useful only when a stable URL is worth the extra
Cloudflare account, DNS, and credential management.

## Apply `m1-min`

The configuration expects the checkout at `~/nix-config`.

```bash
cd ~/nix-config
nix flake check -L --show-trace
sudo darwin-rebuild build --flake .#m1-min
```

For a full activation:

```bash
sudo darwin-rebuild switch --flake .#m1-min
exec zsh
```

When an unrelated nix-darwin activation phase blocks testing, activate only the
Home Manager package:

```bash
nix build \
  .#darwinConfigurations.m1-min.config.home-manager.users.test.home.activationPackage

./result/activate
exec zsh
```

Install or refresh the upstream CLI through the existing module when needed:

```bash
rh-bootstrap
repo-harness --version
```

## Adopt the target repository

The `coding` profile fails closed unless at least one explicitly registered
`read_write` repository contains `.ai/harness/workflow-contract.json`. A registry
grant by itself is not enough; without the marker, `/health` returns
`coding_disabled`.

Do not run the standard initialization wrapper for this MVP without reviewing
its dry-run. On the tested upstream revision, standard mode planned more than
100 repository changes.

### Test minimal adoption without changing the PR checkout

Use a disposable detached worktree first:

```bash
cd ~/nix-config
MVP_WORKTREE=/tmp/nix-config-rh-mvp

git worktree add --detach "$MVP_WORKTREE" HEAD
repo-harness init \
  --repo "$MVP_WORKTREE" \
  --mode minimal \
  --no-codegraph
```

On Repo Harness `0.12.0` from upstream commit
`1789a75100bc767c991104c32df39478ff3bbf32`, this bounded mode created 11
untracked files plus a small `.gitignore` update. It preserved the required
`.gitkeep` sentinels in `.ai/harness/worktrees/` and `.ai/harness/runs/`.

Verify adoption from inside that worktree:

```bash
env -C "$MVP_WORKTREE" repo-harness status --json
```

Require:

```text
.repo.optIn == true
.repo.optInMarker == ".ai/harness/workflow-contract.json"
```

### Known minimal-mode limitation

The tested `repo-harness init --mode minimal` currently exits nonzero during its
final `check-task-workflow --strict` step. Minimal mode writes a full workflow
contract but intentionally omits many standard-mode directories, templates,
policy files, architecture references, and deployment files that the strict
checker requires.

This distinction matters:

- **MCP adoption is valid:** `repo-harness status` reports `optIn: true` and a
  temporary loopback coding server starts successfully for an explicit
  `read_write` grant.
- **Full Repo Harness workflow compliance is not valid:** the strict workflow
  check fails until standard adoption artifacts are installed.

Treat the nonzero initialization result as a known upstream minimal-mode
inconsistency, not as proof that Coding MCP is broken. Do not hide the failure
or claim the repository passes the strict workflow gate.

### Applying adoption to `~/nix-config`

The configured `m1-min` service targets `~/nix-config`; adopting only a
disposable worktree does not enable that service. After reviewing the disposable
diff, either:

1. commit the bounded minimal-adoption files to PR #9; or
2. deliberately adopt the full standard workflow in a separate follow-up.

Do not copy only the marker file. Keep the generated minimal set together so the
repository contract and its scaffolding remain internally understandable.

### Allowed and prohibited operations

Allowed:

- preview initialization before applying it;
- test adoption in a detached disposable worktree;
- grant only an adopted, canonical repository path;
- use `read_write` only for the repository intended for the coding canary;
- keep MCP bound to `127.0.0.1` and expose it only through authenticated HTTPS;
- open managed workspaces from an exact commit SHA;
- test a harmless read, patch, targeted command, and diff;
- verify that `../outside` traversal is rejected;
- remove the disposable worktree after preserving non-secret evidence.

Prohibited:

- do not grant `/Users/test`, `/tmp`, `/`, or another broad parent directory;
- do not expose port `8765` on `0.0.0.0` or a LAN interface;
- do not commit `~/.repo-harness`, OAuth URLs, passphrases, codes, or tokens;
- do not hand-edit authorization revisions in Repo Harness state;
- do not run imperative CodeGraph installers over the Nix-managed installation;
- do not treat CodeGraph indexing as a prerequisite for the MCP coding MVP;
- do not bypass managed-worktree isolation or traversal checks;
- do not claim strict workflow compliance after minimal adoption.

## Verified MCP gates

### Disposable local test

A disposable adopted worktree was registered with explicit `read_write` access,
the user-scoped setup was refreshed through `repo-harness mcp setup chatgpt`, and
a short-lived server was started on `127.0.0.1:8876`. Validation returned:

```text
/health status              ok
profile                     coding
workspaceCoder              true
auth                        oauth
OAuth protected-resource    HTTP 200
```

The test used an alternate port and did not touch the PR checkout. Config and
OAuth token files were restored afterward. Repo Harness `0.12.0` exposes
`mcp access set` but no revoke command, so deleting the disposable worktree can
leave an unusable path entry in `registered-repos.json`; do not hand-edit the
registry or its authorization revision to remove it.

### Adopted `m1-min` checkout and public transport

After applying the reviewed minimal set to `~/nix-config`, the real launchd
service passed local health and OAuth discovery on `127.0.0.1:8765`. The
supported `rh-mcp-quick-restart` path then passed:

```text
HTTP/2 tunnel registration          PASS
20-second publication grace         PASS
five pre-bootstrap probes           PASS (HTTP 421 expected)
public health after bootstrap       PASS
config_ready                        PASS
local_ready                         PASS
tunnel_ready                        PASS
oauth_ready (DCR + PKCE)            PASS
mcp_ready (exact 24-tool schema)     PASS
```

A separate `rh-mcp-quick-test` run also passed. Quick Tunnel URLs are ephemeral,
so obtain the current value with `rh-mcp-quick-url` rather than copying a URL
from this guide.

This proves adoption, explicit access, loopback service, authenticated public
transport, OAuth protocol readiness, and MCP schema readiness. The remaining
manual MVP gate is a visible ChatGPT tool invocation followed by the isolated
read/write/command/diff canary and the rejected `../outside` traversal test.

## Default Quick Tunnel workflow

The normal operator command is:

```bash
rh-mcp-quick-restart
```

It performs the proven runtime sequence:

1. require or recover local MCP health;
2. stop the previous matching Quick Tunnel;
3. start `cloudflared tunnel --protocol http2`;
4. capture the generated `*.trycloudflare.com` URL;
5. require `Registered tunnel connection ... protocol=http2`;
6. wait 20 seconds before the first lookup of the new hostname;
7. require five consecutive public `200` or pre-bootstrap `421` responses;
8. bootstrap Repo Harness with `<quick-url>/mcp`;
9. restart the local MCP service;
10. require the public health response to advertise the same `public_origin`;
11. require the live doctor to reach `mcp_ready`.

The 20-second quiet publication grace is intentional. Runtime validation showed
that immediately querying a newly-issued Quick Tunnel hostname can race DNS
publication and seed a negative resolver cache.

Successful output ends with:

```text
Repo Harness Quick Tunnel ready
Public origin: https://<random>.trycloudflare.com
ChatGPT MCP:   https://<random>.trycloudflare.com/mcp
```

## Test and print the active URL

The authoritative configured URL is:

```bash
rh-mcp-quick-url
```

Run the full non-mutating check:

```bash
rh-mcp-quick-test
```

It requires:

```text
local MCP health       PASS
public MCP health      PASS
public_origin match    PASS
OAuth discovery        PASS
config_ready           PASS
local_ready            PASS
tunnel_ready           PASS
oauth_ready            PASS
mcp_ready              PASS
```

Unlike the original helper, `rh-mcp-quick-test` reads the authoritative endpoint
from `~/.repo-harness/mcp.local.json`, so it can also validate a currently
working manually-created Quick Tunnel.

## Configure ChatGPT

After `rh-mcp-quick-restart`, copy the exact value from:

```bash
rh-mcp-quick-url
```

Use it as the ChatGPT developer-mode MCP URL and keep authentication set to
OAuth.

When the Quick Tunnel hostname changes, update the ChatGPT app URL before
reauthorizing.

## OAuth helper

Click **Sign in with Repo Harness Coding** in ChatGPT.

When the fresh Repo Harness `/authorize?...` page opens:

1. do not submit the browser form;
2. press `Cmd+L`;
3. press `Cmd+C`;
4. run:

```bash
rh-mcp-auth
```

The helper:

- reads the fresh authorization URL from the macOS clipboard;
- clears the clipboard immediately;
- validates that the authorization host matches the current Repo Harness
  `public_origin`;
- requires OAuth authorization-code flow with PKCE `S256`;
- requires the callback host to be `chatgpt.com`;
- reads the local OAuth passphrase without printing it;
- submits `/authorize` with `Origin: https://chatgpt.com`;
- requires a `302` or `303` callback;
- opens the validated ChatGPT callback.

Expected output:

```text
Authorization HTTP status: 302
OAuth accepted; opening ChatGPT callback
```

Never paste the live `/authorize` URL, callback URL, passphrase, authorization
code, or tokens into chat or Git.

## ChatGPT read-only canary

After OAuth succeeds, start a new ChatGPT conversation:

```text
Use Repo Harness Coding and call harness_status.
Do not call any other tool.
Do not modify anything and do not run shell commands.
```

Require a visible `Called tool` event.

Then:

```text
Use Repo Harness Coding and call harness_doctor.
Do not call any other tool.
Do not modify anything and do not run shell commands.
```

A local `mcp_ready` doctor proves transport/schema readiness. The visible
ChatGPT tool event separately proves actual app invocation.

Only after both are green should `open_workspace`, `read`, `apply_patch`, or
`exec_command` be tested.

## Runtime state

Quick Tunnel state is private and local:

```text
~/.local/state/repo-harness-mcp-quick/
├── cloudflared.log
├── cloudflared.pid
└── public-url
```

Repo Harness mutable OAuth/config state remains under:

```text
~/.repo-harness/
```

Do not commit those files.

## Optional: stable custom Cloudflare hostname

The named-tunnel module remains available but is disabled by default:

```nix
services.cloudflared-mcp-tunnel.enable = false;
```

To opt into a stable hostname, first perform the external Cloudflare account
operations:

```bash
scripts/repo-harness-mcp/60-cloudflare-login.sh

scripts/repo-harness-mcp/70-cloudflare-create-tunnel.sh \
  --name repo-harness-coding

scripts/repo-harness-mcp/80-cloudflare-configure-dns.sh \
  --tunnel <tunnel-uuid> \
  --hostname mcp.example.com
```

Then initialize the local named-tunnel runtime state:

```bash
rh-cloudflared-mcp-init \
  --tunnel-id <tunnel-uuid> \
  --hostname mcp.example.com \
  --credentials-file "$HOME/.cloudflared/<tunnel-uuid>.json" \
  --dry-run

rh-cloudflared-mcp-init \
  --tunnel-id <tunnel-uuid> \
  --hostname mcp.example.com \
  --credentials-file "$HOME/.cloudflared/<tunnel-uuid>.json"
```

Enable the module deliberately in the host configuration:

```nix
services.cloudflared-mcp-tunnel = {
  enable = true;
  localHost = "127.0.0.1";
  localPort = 8765;
  autoStart = true;
};
```

Bootstrap Repo Harness with the stable URL:

```bash
rh-mcp-bootstrap \
  --repo ~/nix-config \
  --endpoint https://mcp.example.com/mcp
```

Then use the named-tunnel restart helper instead of the Quick Tunnel helper.

Treat `cert.pem` and the named-tunnel credential JSON as secrets. They remain
outside Git and `/nix/store`.

## Rollback

Nix rollback restores the previous service definitions:

```bash
sudo darwin-rebuild --rollback
```

For local Repo Harness cleanup/revocation preview:

```bash
scripts/repo-harness-mcp/140-cleanup-or-rollback.sh \
  --repo ~/nix-config \
  --revoke-write \
  --remove-generated-cloudflared-config \
  --dry-run
```

The rollback helper does not delete external Cloudflare tunnels, DNS records,
login certificates, or credential JSON.
