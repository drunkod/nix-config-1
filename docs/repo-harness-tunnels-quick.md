# Repo Harness tunnel variants: short tutorial

Both variants expose the local loopback MCP service over authenticated HTTPS.
Choose one.

## Quick Tunnel — default

No Cloudflare account, domain, DNS route, UUID, or credential file is required.
The URL changes whenever the tunnel is replaced.

On the first setup, create enabled local Coding config before the helper's local
health gate:

```bash
repo-harness-mcp-bootstrap \
  --repo /absolute/repository \
  --endpoint https://mcp.invalid/mcp
repo-harness-mcp-restart
repo-harness-mcp-quick-restart
repo-harness-mcp-quick-test
repo-harness-mcp-quick-url
```

`mcp.invalid` is only a local bootstrap placeholder. Never configure ChatGPT
with it. If enabled Coding config already exists, start at
`repo-harness-mcp-quick-restart`.

Update the ChatGPT app after a URL change and complete fresh OAuth with:

```bash
repo-harness-mcp-chatgpt-auth
```

Use Quick Tunnel for development and testing.

## Reuse the current Quick Tunnel

When only repository access changed and the endpoint is healthy:

```bash
ENDPOINT="$(repo-harness-mcp-quick-url)"
repo-harness-mcp-bootstrap --repo /absolute/repository --endpoint "$ENDPOINT"
unset ENDPOINT
repo-harness-mcp-restart
repo-harness-mcp-quick-test
```

Do not replace a healthy endpoint unnecessarily.

## Named Tunnel — optional

Use this only when a stable custom hostname is worth Cloudflare account, DNS,
and credential management.

### 1. External Cloudflare operations

```bash
scripts/repo-harness-mcp/60-cloudflare-login.sh
scripts/repo-harness-mcp/70-cloudflare-create-tunnel.sh \
  --name repo-harness-coding
scripts/repo-harness-mcp/80-cloudflare-configure-dns.sh \
  --tunnel <uuid> \
  --hostname mcp.example.com
```

### 2. Enable the module and rebuild

The initializer is installed only when the module is enabled:

```nix
services.cloudflared-mcp-tunnel.enable = true;
```

Rebuild/activate `m1-min`.

### 3. Initialize Nix runtime parameters

```bash
cloudflared-mcp-tunnel-init \
  --tunnel-id <uuid> \
  --hostname mcp.example.com \
  --credentials-file "$HOME/.cloudflared/<uuid>.json" \
  --dry-run

cloudflared-mcp-tunnel-init \
  --tunnel-id <uuid> \
  --hostname mcp.example.com \
  --credentials-file "$HOME/.cloudflared/<uuid>.json"
```

Then bootstrap the stable endpoint and restart:

```bash
repo-harness-mcp-bootstrap \
  --repo /absolute/repository \
  --endpoint https://mcp.example.com/mcp

repo-harness-mcp-restart
cloudflared-mcp-tunnel-restart
repo-harness-mcp-doctor
```

## Do not use the historical path as canonical

These scripts are superseded for managed operation:

```text
90-cloudflare-write-config.sh
100-cloudflare-run-tunnel.sh
110-configure-chatgpt-endpoint.sh
```

`100` remains a foreground diagnostic only. The Nix named-tunnel helper owns the
runtime parameter/config flow.

## Security

Never commit Cloudflare certificates, credential JSON, generated runtime YAML,
Quick Tunnel state, MCP endpoint values, or OAuth state. Keep MCP itself bound
to loopback.
