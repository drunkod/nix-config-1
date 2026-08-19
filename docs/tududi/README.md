# Tududi MCP on `m1-min`

This directory contains the canonical Tududi MCP setup and tunnel guides for the `m1-min` profile.

The two `mcp-proxy` public variants below were tested end-to-end on `m1-min` on 2026-08-19.

## Choose a connection

| Goal | Command / path | Public URL | Authentication | Status |
| --- | --- | --- | --- | --- |
| Local MCP | `td-mcp-stdio` | none | Tududi token loaded locally from SOPS | Recommended local path |
| Fastest ChatGPT test | `tududi-mcp-proxy-public` | `https://<generated>.tunnel.gla.ma/mcp` | none | Tested |
| ChatGPT test through Cloudflare | `tududi-mcp-proxy-local` + `cloudflared` | `https://<generated>.trycloudflare.com/mcp` | none | Tested |
| Raw Tududi HTTP MCP for clients that can send the Tududi token | `td-mcp-quick-*` | `https://<generated>.trycloudflare.com/api/mcp` | `Authorization: Bearer tt_...` | Tested transport |
| Legacy custom anonymous gateway | `td-chatgpt-quick-*` | `https://<generated>.trycloudflare.com/api/mcp` | none | Superseded by `mcp-proxy` |
| Stable/production public endpoint | named tunnel + proper MCP auth | stable hostname | OAuth / access policy | Not part of this MVP |

For ChatGPT MVP testing, prefer one of the two `mcp-proxy` guides. Both reuse `tududi-mcp-stdio`, so the Tududi `tt_...` API token remains local and is loaded from the existing SOPS runtime secret.

## Canonical guides

- [Tududi on `m1-min`](m1-min.md) — service, storage, SOPS, and local MCP.
- [ChatGPT via `mcp-proxy` Public Tunnel](mcp-proxy-public-tunnel.md) — simplest one-command public tunnel.
- [ChatGPT via Cloudflare Quick Tunnel](mcp-proxy-cloudflare-quick-tunnel.md) — separate local `mcp-proxy` and `cloudflared` processes.
- [ChatGPT authentication and production notes](chatgpt-plugin-mcp.md) — what changes when moving beyond the anonymous MVP.
- [First login](how-first-login.md) — initial Tududi account setup.

## Common prerequisites

```bash
cd ~/nix-config
git switch agent/tududi-mcp-proxy-mvp
git pull --ff-only
sudo darwin-rebuild switch --flake .#m1-min
exec zsh -l
```

Verify the installed commands:

```bash
td-health
command -v tududi-mcp-stdio
command -v tududi-mcp-proxy-local
command -v tududi-mcp-proxy-public
```

## Safety boundary

The two `mcp-proxy` public MVP paths intentionally add no public authentication. Anyone who obtains the temporary URL can reach the exposed Tududi MCP tools, including write tools.

Use them only for short tests and stop the public process when finished.

Do not paste the Tududi `tt_...` API token into ChatGPT. It remains a local SOPS-managed credential used by `tududi-mcp-stdio`.

## Code map

- `modules/services/tududi.nix` — Tududi app, SOPS integration, and `tududi-mcp-stdio`.
- `modules/services/tududi-mcp-proxy.nix` — local and Public Tunnel `mcp-proxy` wrappers.
- `modules/services/tududi-mcp-quick.nix` — direct Tududi HTTP Quick Tunnel with Tududi bearer-token auth.
- `modules/services/tududi-chatgpt-quick.nix` — older custom anonymous gateway; retained for now but no longer the preferred MVP.
- `modules/services/cloudflared-mcp-tunnel.nix` — optional stable named Cloudflare tunnel machinery.
- `modules/hosts/darwin/m1/default.nix` — enables the Tududi modules for `m1-min`.
