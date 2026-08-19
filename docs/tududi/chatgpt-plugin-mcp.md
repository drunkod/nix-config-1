# ChatGPT authentication and production notes for Tududi MCP

The public `mcp-proxy` guides in this directory are intentionally fast, anonymous MVP paths. They are suitable for short developer tests, not for a stable deployment.

For the tested MVP flows, start here:

- [`mcp-proxy` Public Tunnel](mcp-proxy-public-tunnel.md)
- [Cloudflare Quick Tunnel](mcp-proxy-cloudflare-quick-tunnel.md)

## Current `m1-min` authentication model

The local Tududi stdio server is started by:

```bash
tududi-mcp-stdio
```

That wrapper reads the Tududi `tt_...` API token from the SOPS runtime secret and starts Tududi's stdio MCP server. The token remains local to the Mac.

The `mcp-proxy` wrappers sit in front of this stdio server:

```text
public MCP request
  -> mcp-proxy
  -> tududi-mcp-stdio
  -> local SOPS token
  -> Tududi
```

For the MVP, `mcp-proxy` does not authenticate the incoming public request.

## Native Tududi HTTP MCP is a different path

The repository also provides the direct Tududi HTTP Quick Tunnel helpers:

```bash
td-mcp-quick-restart
td-mcp-quick-url
td-mcp-quick-test
td-mcp-quick-stop
```

Those expose Tududi's own `/api/mcp` endpoint and expect the Tududi bearer API token. They are useful for MCP clients that can set the required bearer header, but they are not the same as the anonymous ChatGPT MVP paths documented here.

## Moving beyond the MVP

For a durable public ChatGPT connection, use a stable HTTPS hostname and proper MCP authentication instead of relying on possession of a random tunnel URL.

Two reasonable directions are:

1. Keep Tududi private and use a secure/private MCP tunnel that forwards to `tududi-mcp-stdio`.
2. Put a proper OAuth-capable MCP resource-server/gateway in front of Tududi and expose that through a stable named tunnel.

The current `m1-min` Tududi service has OIDC disabled, so the existing deployment should not be treated as a ready-to-use public OAuth MCP resource server.

## Cloudflare production direction

Quick Tunnels are for development. For a stable deployment, use the repository's named Cloudflare tunnel machinery or replace it with a dedicated Tududi MCP named-tunnel module that points at an MCP-only local gateway/proxy instead of the complete Tududi web origin.

A production path should also define an explicit authentication boundary before exposing write-capable Tududi tools.

## What not to do

- Do not paste the Tududi `tt_...` API token into ChatGPT.
- Do not leave the anonymous MVP tunnel running after testing.
- Do not treat a random tunnel hostname as an authentication mechanism.
- Do not expose the full Tududi HTTP origin when an MCP-only listener is sufficient.

## Related files

- `modules/services/tududi.nix`
- `modules/services/tududi-mcp-proxy.nix`
- `modules/services/tududi-mcp-quick.nix`
- `modules/services/cloudflared-mcp-tunnel.nix`
- `modules/hosts/darwin/m1/default.nix`
