# Repo Harness MCP coding profile on `m1-min`

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

Preview first:

```bash
scripts/repo-harness-mcp/20-initialize-repo-harness.sh \
  --repo ~/nix-config \
  --dry-run
```

Apply only after reviewing the generated repository contract:

```bash
scripts/repo-harness-mcp/20-initialize-repo-harness.sh \
  --repo ~/nix-config \
  --apply
```

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
