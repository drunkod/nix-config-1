# Tududi on `m1-min`

This profile integrates Tududi as a native Home Manager/nix-darwin user service and keeps it independent from Repo Harness MCP.

## Architecture

- Tududi app: `http://127.0.0.1:3002`
- Persistent SQLite: `~/.local/share/tududi/db/production.sqlite3`
- Uploads: `~/.local/share/tududi/uploads`
- Logs: `~/.local/state/tududi`
- Local MCP: stdio via `tududi-mcp-stdio`, registered as `programs.mcp.servers.tududi`
- Remote MCP: optional Quick Tunnel at `https://<random>.trycloudflare.com/api/mcp`
- Remote authentication: `Authorization: Bearer tt_...`

Repo Harness remains on `127.0.0.1:8765` and continues to use its own Quick Tunnel/OAuth workflow.

## First activation

The upstream Tududi package comes from the researched `feature/nixos-module` revision `2fa53e92223773c5a5a288e9c0252bc2ea952064`. The repository intentionally does not make Tududi's nixpkgs input follow this flake's `nixos-unstable` input yet.

Because this change adds a new flake input, refresh the lock file once on a machine with Nix/network access. Current Nix uses:

```bash
nix flake update tududi
```

Commit the resulting `flake.lock` change with the integration once it has been generated on the M1.

You can validate the upstream native package independently before switching the host:

```bash
NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 \
  nix build github:dlip/tududi/2fa53e92223773c5a5a288e9c0252bc2ea952064#tududi \
  --impure \
  --show-trace
```

The upstream package is marked Linux-only even though it builds successfully on Apple Silicon. The local adapter therefore changes only `meta.platforms` to permit Darwin evaluation and deliberately preserves the complete upstream `buildNpmPackage` build inputs/hooks. Replacing `nativeBuildInputs` would remove the npm setup hook and cause `npm: command not found` during `installPhase`.

Activate the profile:

```bash
darwin-rebuild switch --flake .#m1-min
```

Check the service and print the one-time bootstrap credentials:

```bash
td-health
td-bootstrap-credentials
open http://127.0.0.1:3002
```

The initial account is `admin@tududi.invalid`, a reserved non-deliverable domain. On first start, the module generates a random bootstrap password at `~/.local/share/tududi/bootstrap-admin-password` (mode `0600`), provisions that verified user as admin, and writes a marker so later restarts do **not** overwrite password changes.

The bootstrap configuration also generates a persistent session secret at `~/.local/share/tududi/session-secret`. This avoids putting generated secrets in the Nix store while allowing the app to start before SOPS keys exist.

## Configure SOPS secrets

Log in with the bootstrap credentials, then create a token under **Profile -> API Keys**. Tududi tokens used by MCP start with `tt_`. Before enabling declarative admin-password reconciliation, set `services.tududi.adminEmail` to the account email you want Nix to manage (or keep `admin@tududi.invalid`).

Edit the existing encrypted file with SOPS and add:

```yaml
tududi:
  session-secret: <long-random-secret>
  admin-password: <admin-password>
  api-token: <tt_...>
```

For example, generate a session secret locally with:

```bash
openssl rand -hex 64
```

Do not commit plaintext secret values. Use the existing SOPS/Age workflow for `secrets/default.yaml`.

After all three encrypted keys exist, change the `m1-min` block to:

```nix
services.tududi.sops.enable = true;
```

and rebuild. The module then reads all secret values from SOPS runtime files; the values are never interpolated into Nix derivations or MCP `env` attributes. The obsolete bootstrap password and locally generated session-secret files are removed after the corresponding explicit secret sources become active.

The stdio MCP registration is already present. Verify it directly with:

```bash
td-mcp-stdio
```

If the API token is not configured yet, the wrapper fails closed with instructions rather than starting an unauthenticated MCP process.

## Quick Tunnel remote MCP

Quick Tunnel is available but deliberately not auto-started, because every replacement gets a new random hostname. It requires `services.tududi.mcp.enable = true`, because that option also enables Tududi's HTTP `/api/mcp` feature flag.

Start or replace it:

```bash
td-mcp-quick-restart
```

Print the current MCP endpoint:

```bash
td-mcp-quick-url
```

Test local health, public health, and—when the SOPS API token is available—authenticated MCP status:

```bash
td-mcp-quick-test
```

The authenticated status test requires Tududi to report `{ "enabled": true }`; an authenticated but disabled MCP endpoint is treated as a failure.

Stop it:

```bash
td-mcp-quick-stop
```

The Quick Tunnel helpers verify that a saved PID still belongs to a `cloudflared tunnel --url <local Tududi origin>` process before sending a signal, so a stale PID file cannot kill an unrelated process after PID reuse.

Remote clients use the printed URL and the Tududi API token:

```text
POST https://<random>.trycloudflare.com/api/mcp
Authorization: Bearer tt_...
```

Do not reuse the Repo Harness OAuth/bootstrap helpers for Tududi. Tududi's HTTP MCP endpoint accepts its own Bearer API token, while Repo Harness remains a separate service and auth domain.

## Security boundary

The MVP Quick Tunnel points `cloudflared` directly at `127.0.0.1:3002`, so the generated hostname publishes the complete Tududi HTTP origin, not only `/api/mcp`. Tududi authentication still protects authenticated API routes, but the exposure is intentionally broader than a dedicated MCP-only reverse proxy.

For a hardened stable deployment, place a local reverse proxy in front of Tududi and expose only `/api/mcp`, `/api/health`, and any explicitly required OAuth discovery paths, then point Cloudflare at that proxy instead.
