# Tududi on `m1-min`

This profile runs Tududi as a native Home Manager/nix-darwin user service and keeps it independent from Repo Harness MCP.

For tunnel selection and the canonical test guides, see [the Tududi MCP index](README.md).

## Architecture

- Tududi app: `http://127.0.0.1:3002`
- Persistent SQLite: `~/.local/share/tududi/db/production.sqlite3`
- Uploads: `~/.local/share/tududi/uploads`
- Logs: `~/.local/state/tududi`
- Local MCP: `tududi-mcp-stdio`, registered as `programs.mcp.servers.tududi`
- ChatGPT MVP bridge: `mcp-proxy` on `127.0.0.1:8080/mcp`
- Public MVP choices:
  - built-in `mcp-proxy --tunnel` -> `*.tunnel.gla.ma/mcp`
  - Cloudflare Quick Tunnel -> `*.trycloudflare.com/mcp`
- Native Tududi HTTP MCP: `/api/mcp`, authenticated with the Tududi `tt_...` bearer token

Repo Harness remains a separate service with its own MCP and tunnel/authentication configuration.

## Activate the profile

```bash
cd ~/nix-config
git switch agent/tududi-mcp-proxy-mvp
git pull --ff-only
sudo darwin-rebuild switch --flake .#m1-min
exec zsh -l
```

Check Tududi:

```bash
td-health
open http://127.0.0.1:3002
```

## First login

The initial account is `admin@tududi.invalid`. On first start, the module generates a bootstrap password outside the Nix store and provisions the user as admin.

Print the bootstrap credentials when needed:

```bash
td-bootstrap-credentials
```

See [First login](how-first-login.md) for the short setup guide.

## SOPS secrets

The `m1-min` profile uses the shared encrypted `secrets/default.yaml` for:

```yaml
tududi:
  session-secret: <encrypted value>
  admin-password: <encrypted value>
  api-token: <encrypted tt_... value>
```

The values are materialized into runtime secret files by SOPS/Home Manager. The Tududi API token is not interpolated into the Nix store.

Do not commit plaintext secret values.

## Local MCP

The primary local MCP command is:

```bash
td-mcp-stdio
```

The underlying `tududi-mcp-stdio` wrapper reads the SOPS-managed API token locally and starts Tududi's stdio MCP server.

This is the common upstream for both tested `mcp-proxy` public variants.

## Recommended ChatGPT MVP: `mcp-proxy` Public Tunnel

Start:

```bash
tududi-mcp-proxy-public
```

It creates a temporary URL:

```text
https://<generated>.tunnel.gla.ma/mcp
```

This was tested end-to-end with ChatGPT. See [`mcp-proxy` Public Tunnel](mcp-proxy-public-tunnel.md).

The public endpoint has no additional authentication. Stop it with `Ctrl-C` after testing.

## Cloudflare Quick Tunnel + `mcp-proxy`

Start the local bridge:

```bash
tududi-mcp-proxy-local
```

Then, in another terminal:

```bash
cloudflared tunnel \
  --protocol http2 \
  --url http://127.0.0.1:8080
```

Use:

```text
https://<generated>.trycloudflare.com/mcp
```

This path was also tested end-to-end. Earlier attempts showed temporary hostname/DNS warm-up, so test the public MCP `initialize` request before adding the URL to ChatGPT.

See [Cloudflare Quick Tunnel](mcp-proxy-cloudflare-quick-tunnel.md).

## Native Tududi HTTP Quick Tunnel

The older `td-mcp-quick-*` helpers expose Tududi's own HTTP origin through TryCloudflare:

```bash
td-mcp-quick-restart
td-mcp-quick-url
td-mcp-quick-test
td-mcp-quick-stop
```

Remote MCP requests use Tududi's native endpoint:

```text
POST https://<generated>.trycloudflare.com/api/mcp
Authorization: Bearer tt_...
```

This is appropriate for clients that can send the Tududi bearer token. It is separate from the anonymous `mcp-proxy` ChatGPT MVP.

The direct Quick Tunnel publishes the complete local Tududi HTTP origin, not only `/api/mcp`, so keep it stopped when it is not needed.

## Legacy custom ChatGPT gateway

The `td-chatgpt-quick-*` commands are still installed, but the custom gateway is now superseded by `mcp-proxy` for new MVP testing. See [Legacy custom TryCloudflare MVP](chatgpt-trycloudflare-mvp-unsafe.md).

## Production direction

For a stable public endpoint:

- use a stable named tunnel rather than a random development hostname;
- expose an MCP-only listener instead of the full Tududi web origin;
- add a real authentication boundary before write-capable tools; and
- keep the Tududi `tt_...` credential behind that local boundary.

See [ChatGPT authentication and production notes](chatgpt-plugin-mcp.md).
