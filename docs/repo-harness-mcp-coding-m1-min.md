# Repo Harness MCP coding profile on `m1-min`

This runbook converts the upstream manual ChatGPT MCP `coding` tutorial into a
reproducible `nix-darwin`/Home Manager configuration while preserving the
security boundaries of Repo Harness.

## Source authority

The implementation was reconciled against:

- `drunkod/repo-harness` branch `agent/chatgpt-github-create-mvp`;
- commit `d66aeab6afd137032b6692b581b82b8177272131`;
- `docs/repo-harness-chatgpt-mcp-setup.md`;
- `docs/repo-harness-chatgpt-coding-mcp-tutorial.md`.

The configuration repository base is
`agent/use-repo-harness-chatgpt-create-mvp` at
`e34b0626bad5b4a144bb7193c5ea61ba09eb0479`.

## What Nix now owns

For `m1-min`, Home Manager owns:

- `pkgs.cloudflared` and the existing Repo Harness launcher;
- the loopback MCP launchd agent;
- the Cloudflare Tunnel launchd agent;
- restart, health, doctor, and bootstrap helpers;
- runtime directories and log locations;
- static assertions that reject a public MCP bind, an endpoint without `/mcp`,
  an implicit repository grant, and runtime files in `/nix/store`;
- `bash -n` and ShellCheck flake checks for the prototype scripts.

Nix does **not** create OAuth credentials, log into Cloudflare, create a tunnel,
change DNS, or configure the ChatGPT developer-mode app.

## Four network values

Keep these values distinct:

| Name | Example | Owner |
|---|---|---|
| Local origin | `http://127.0.0.1:8765` | `services.repo-harness-mcp` |
| Tunnel upstream | `http://127.0.0.1:8765` | generated runtime cloudflared YAML |
| Public origin | `https://mcp.example.com` | Cloudflare DNS/tunnel |
| ChatGPT MCP URL | `https://mcp.example.com/mcp` | Repo Harness setup and ChatGPT app |

Only the last value is passed to `repo-harness mcp setup chatgpt`. The public
origin must not include `/mcp`; the ChatGPT MCP URL must include it.

## Apply `m1-min`

The host expects the configuration checkout at `~/nix-config`. Change
`services.repo-harness-mcp.repoPath` in the host module when the checkout lives
elsewhere.

```bash
cd ~/nix-config
nix flake check
sudo darwin-rebuild build --flake .#m1-min
sudo darwin-rebuild switch --flake .#m1-min
exec zsh
```

Install or refresh the upstream CLI through the existing module:

```bash
rh-bootstrap
repo-harness --version
```

No second Repo Harness installation is introduced by the MCP modules.

## Adopt the target repository

Preview first:

```bash
scripts/repo-harness-mcp/20-initialize-repo-harness.sh \
  --repo ~/nix-config \
  --dry-run
```

Apply only after reviewing the generated contract:

```bash
scripts/repo-harness-mcp/20-initialize-repo-harness.sh \
  --repo ~/nix-config \
  --apply
```

## Create the named Cloudflare Tunnel

These are external, interactive operations and are not run by activation:

```bash
scripts/repo-harness-mcp/60-cloudflare-login.sh
scripts/repo-harness-mcp/70-cloudflare-create-tunnel.sh \
  --name repo-harness-coding
scripts/repo-harness-mcp/80-cloudflare-configure-dns.sh \
  --tunnel <tunnel-uuid> \
  --hostname <stable-hostname>
```

The DNS script does not request overwrite behavior. A conflicting hostname
therefore fails closed and must be resolved deliberately in Cloudflare.

Create the local runtime parameter file used by the launchd agent:

```bash
rh-cloudflared-mcp-init \
  --tunnel-id <tunnel-uuid> \
  --hostname <stable-hostname> \
  --credentials-file "$HOME/.cloudflared/<tunnel-uuid>.json" \
  --dry-run

rh-cloudflared-mcp-init \
  --tunnel-id <tunnel-uuid> \
  --hostname <stable-hostname> \
  --credentials-file "$HOME/.cloudflared/<tunnel-uuid>.json"
```

The helper stores only the UUID, hostname, and credentials **path** in
`~/.config/repo-harness/cloudflared-mcp.env`. The credentials JSON remains in
`~/.cloudflared` and is never copied into Git or the Nix store. The launchd
runner generates `~/.config/cloudflared/repo-harness-mcp.yml` at runtime with
mode `0600`.

The existing `services.sops` module remains the approved secret mechanism. If
you later encrypt the tunnel credentials with sops-nix, pass the materialized
`config.sops.secrets.<name>.path` to `--credentials-file`; never place decrypted
JSON or a tunnel token in a normal Nix string. The native `~/.cloudflared` file
is the bootstrap-compatible default, not a second committed secret store.

## Configure the Repo Harness coding profile

Preview the exact setup command:

```bash
rh-mcp-bootstrap \
  --repo ~/nix-config \
  --endpoint https://<stable-hostname>/mcp \
  --dry-run
```

Apply it:

```bash
rh-mcp-bootstrap \
  --repo ~/nix-config \
  --endpoint https://<stable-hostname>/mcp
```

This always supplies all of the fail-closed coding inputs:

```text
--scope user
--profile coding
--grant-read-write <exact repo path>
--host 127.0.0.1
--port 8765
--auth oauth (at serve time)
```

Read the OAuth passphrase locally and paste it directly into the ChatGPT
authorization page. Do not paste it into chat or commit it:

```bash
jq -r .passphrase ~/.repo-harness/mcp.oauth.json
```

## Start and verify services

After local bootstrap files exist:

```bash
rh-mcp-restart
rh-mcp-health
rh-cloudflared-mcp-restart
rh-mcp-doctor
```

Logs:

```text
~/.local/state/repo-harness-mcp/
~/.local/state/cloudflared-mcp-tunnel/
```

The tunnel runner waits for the local `/health` endpoint before starting.
Repo Harness remains bound to loopback; Cloudflare is the only public ingress.

## Configure the ChatGPT app manually

In ChatGPT Developer mode:

1. Create or refresh the app named `repo-harness-coding`.
2. Use `https://<stable-hostname>/mcp`.
3. Select OAuth.
4. Enter the local passphrase directly in the authorization page.
5. Keep confirmation enabled for writes and shell commands.
6. Refresh the schema and start a new chat.

A successful local doctor is not proof of ChatGPT invocation. Require a visible
`Called tool` event for `open_workspace`/`read` before any mutation test.

## Smoke test

Local checks:

```bash
scripts/repo-harness-mcp/130-run-coding-profile-smoke-test.sh \
  --repo ~/nix-config
```

Then use the upstream read-only ChatGPT prompt: discover the exact repo,
`open_workspace` in `worktree` mode from an approved base, read instructions
and `README.md`, and stop without editing or running shell commands.

Only after that succeeds should a harmless file under `tasks/notes/` be created.
Do not commit or push during the first exercise.

## Deterministic versus manual operations

| Operation | Classification | Implementation |
|---|---|---|
| Packages, wrapper commands, service definitions | Deterministic | Nix/Home Manager |
| Loopback host, port, profile and explicit repo path | Deterministic | Nix options/assertions |
| Runtime directories and logs | Deterministic | Home Manager activation |
| OAuth passphrase/token generation | Local mutable state | `rh-mcp-bootstrap` |
| Cloudflare browser login | Interactive external | script `60` |
| Tunnel creation | External account mutation | script `70` |
| DNS route | External DNS mutation | script `80` |
| Tunnel UUID/hostname selection | Local operator state | `rh-cloudflared-mcp-init` |
| ChatGPT app creation/authorization | Manual external UI | this runbook |

## Rollback

Nix rollback restores the previous launchd definitions:

```bash
sudo darwin-rebuild --rollback
```

For a safe local preview:

```bash
scripts/repo-harness-mcp/140-cleanup-or-rollback.sh \
  --repo ~/nix-config \
  --revoke-write \
  --remove-generated-cloudflared-config \
  --dry-run
```

Apply only the selected local actions with `--apply`. The script never deletes
Cloudflare tunnels, DNS records, login certificates, or credentials.
