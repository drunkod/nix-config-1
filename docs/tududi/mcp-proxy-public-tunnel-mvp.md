# Tududi MCP Proxy MVP examples

Two minimal ways to expose the existing Tududi stdio MCP server.

## Version A: existing Cloudflare Quick Tunnel

```text
ChatGPT
  -> cloudflared trycloudflare.com
  -> mcp-proxy HTTP bridge
  -> tududi-mcp-stdio
  -> Tududi
```

Install:

```bash
npm install -g mcp-proxy
```

Run:

```bash
mcp-proxy \
  --port 8080 \
  --stateless \
  -- \
  tududi-mcp-stdio
```

Expose with existing repo helper pattern:

```bash
cloudflared tunnel --url http://127.0.0.1:8080
```

Use:

```text
https://<random>.trycloudflare.com/mcp
```

## Version B: mcp-proxy Public Tunnel

`mcp-proxy` can create its own public tunnel.

Run:

```bash
mcp-proxy \
  --port 8080 \
  --tunnel \
  --stateless \
  -- \
  tududi-mcp-stdio
```

Result:

```text
https://abcdefghij.tunnel.gla.ma/mcp
```

Use this URL in the MCP client.

## Nix/Home Manager MVP

Add package:

```nix
home.packages = [ pkgs.nodePackages.npm ];
```

Create a wrapper:

```nix
pkgs.writeShellApplication {
  name = "tududi-mcp-proxy";
  text = ''
    exec mcp-proxy \
      --port 8080 \
      --stateless \
      -- \
      tududi-mcp-stdio
  '';
}
```

Tunnel variant:

```nix
pkgs.writeShellApplication {
  name = "tududi-mcp-proxy-public";
  text = ''
    exec mcp-proxy \
      --port 8080 \
      --tunnel \
      --stateless \
      -- \
      tududi-mcp-stdio
  '';
}
```

The existing `tududi-mcp-stdio` wrapper remains responsible for loading `TUDUDI_API_TOKEN` from SOPS.

## Test

```bash
tududi-mcp-proxy-public
```

Copy the generated `tunnel.gla.ma` URL and add `/mcp`.

Stop with Ctrl-C.

This is an MVP test only. The public URL has no additional authentication layer.