# Legacy custom TryCloudflare MVP

This document is retained only to explain the older `td-chatgpt-quick-*` commands.

The custom anonymous gateway in `modules/services/tududi-chatgpt-quick.nix` was useful for the first ChatGPT transport test, but it duplicates MCP server/gateway logic that `mcp-proxy` now provides more simply.

For new tests, use one of the canonical guides instead:

- [`mcp-proxy` Public Tunnel](mcp-proxy-public-tunnel.md)
- [Cloudflare Quick Tunnel](mcp-proxy-cloudflare-quick-tunnel.md)

## Legacy commands

The old module still exposes:

```bash
td-chatgpt-quick-restart
td-chatgpt-quick-test
td-chatgpt-quick-url
td-chatgpt-quick-stop
```

Its flow is:

```text
ChatGPT
  -> temporary trycloudflare.com URL
  -> custom anonymous Node MCP gateway
  -> Tududi MCP tool registry
  -> SOPS-managed Tududi API token
```

It is intentionally unauthenticated and should not be used as a long-running public endpoint.

## Why it is superseded

The tested `mcp-proxy` integration gives the same useful MVP result while reusing the existing `tududi-mcp-stdio` server directly:

```text
ChatGPT
  -> temporary public tunnel
  -> mcp-proxy
  -> tududi-mcp-stdio
  -> Tududi
```

That avoids maintaining a second MCP implementation in this repository.

The legacy module can be removed in a later cleanup after there are no remaining users or scripts depending on the `td-chatgpt-quick-*` command names.
