# Touchpoint + ChatGPT on `m1-min` with `mcp-proxy`

This branch adds Touchpoint to the `m1-min` Home Manager configuration and provides two temporary public MCP transports for fast ChatGPT developer testing:

1. the repository's existing Cloudflare Quick Tunnel pattern (`*.trycloudflare.com`); and
2. `punkpeye/mcp-proxy`'s built-in Public Tunnel (`*.tunnel.gla.ma`).

Both variants are intentionally **unauthenticated developer endpoints**. Touchpoint can read and control the macOS desktop, so stop the tunnel immediately after testing.

## Architecture

### Version A — Cloudflare Quick Tunnel

```text
ChatGPT
  |
  | HTTPS, no auth
  v
https://<random>.trycloudflare.com/mcp
  |
cloudflared Quick Tunnel
  |
  v
http://127.0.0.1:8081/mcp
  |
mcp-proxy --server stream
  |
  | stdio
  v
touchpoint-mcp
  |
  v
macOS Accessibility (AX) + CGEvent
```

### Version B — mcp-proxy Public Tunnel

```text
ChatGPT
  |
  | HTTPS, no auth
  v
https://abcdefghij.tunnel.gla.ma/mcp
  |
mcp-proxy --tunnel --server stream
  |
  | stdio
  v
touchpoint-mcp
  |
  v
macOS Accessibility (AX) + CGEvent
```

The actual `tunnel.gla.ma` hostname is generated at runtime. `https://abcdefghij.tunnel.gla.ma` is only the example shape used by upstream `mcp-proxy` documentation.

## Why the Nix setup is shaped this way

Touchpoint 0.3.0 requires Python 3.10+ and publishes the `touchpoint-mcp` console command. On macOS it uses the native Accessibility/AX backend and CGEvent input through PyObjC.

The Nix module uses Python 3.12 but installs `touchpoint-py==0.3.0` into a stable user venv:

```text
~/.local/share/touchpoint/venv
```

This is a practical compromise for an alpha Python package:

- Nix declaratively controls the Python version, wrappers, configuration, and tunnel helpers.
- The Touchpoint PyPI version is pinned instead of installing an unbounded latest release.
- `pip` is run only when you explicitly run `tp-install`; `darwin-rebuild` does not depend on PyPI/network access.
- The venv path stays stable across Nix generations, which is useful while testing macOS Accessibility permissions.

The proxy is kept **stateful**. Do not add `--stateless` for this setup: Touchpoint's MCP layer keeps short element aliases, snapshot baselines, and other session state in memory.

The proxy is also restricted to Streamable HTTP:

```text
--server stream
```

so ChatGPT uses `/mcp` and the Cloudflare variant does not depend on long-lived SSE.

## Step 1 — checkout and rebuild

```bash
cd ~/nix-config
git fetch origin
git switch agent/integrate-touchpoint-m1-min
git pull --ff-only

darwin-rebuild switch --flake .#m1-min
exec zsh -l
```

If you normally use `nh`:

```bash
nh darwin switch .#m1-min
exec zsh -l
```

## Step 2 — install the pinned Touchpoint package

Run once after the first rebuild, and again if the configured Touchpoint/Python version changes:

```bash
tp-install
```

The installer creates/recreates:

```text
~/.local/share/touchpoint/venv
```

and installs exactly:

```text
touchpoint-py==0.3.0
```

Verify the MCP wrapper exists:

```bash
command -v touchpoint-mcp-nix
```

## Step 3 — grant macOS Accessibility permission

Open:

```text
System Settings -> Privacy & Security -> Accessibility
```

Grant the required Accessibility permission for the process you use to run Touchpoint.

Then run:

```bash
tp-diagnostics
```

Touchpoint should report its macOS backend/input diagnostics instead of an accessibility permission failure.

The `m1-min` configuration defaults to:

```text
TOUCHPOINT_MODE=no-vision
TOUCHPOINT_CDP_DISCOVER=true
TOUCHPOINT_AX_MESSAGING_TIMEOUT=1.0
```

`no-vision` is intentional for this test: ChatGPT receives compact structured accessibility snapshots rather than needing screenshots for every step.

## Optional local stdio check

You can start Touchpoint's MCP server directly:

```bash
tp-mcp
```

It speaks MCP over stdio, so it will normally sit waiting for an MCP client. Press `Ctrl-C` to stop it.

---

# Version A — existing Cloudflare Quick Tunnel

## A1 — start mcp-proxy + Cloudflare

```bash
tp-mcp-cf-restart
```

This command:

1. stops any previous Touchpoint test tunnel;
2. starts stateful `mcp-proxy` on `127.0.0.1:8081`;
3. starts `cloudflared tunnel --url http://127.0.0.1:8081`;
4. waits for the random `*.trycloudflare.com` hostname;
5. checks the public `/ping` endpoint; and
6. prints the ChatGPT MCP URL.

Expected shape:

```text
Touchpoint MCP via Cloudflare Quick Tunnel is ready
ChatGPT MCP URL: https://random-words.trycloudflare.com/mcp
Ping:            https://random-words.trycloudflare.com/ping
```

## A2 — smoke test

```bash
tp-mcp-cf-test
```

Then print only the MCP URL:

```bash
tp-mcp-cf-url
```

Example:

```text
https://random-words.trycloudflare.com/mcp
```

## A3 — connect from ChatGPT

In ChatGPT Developer mode, create a developer MCP/app connection using the public server URL returned by:

```bash
tp-mcp-cf-url
```

Use **no authentication** for this temporary test.

After tool discovery, start with read/orientation requests such as:

```text
List the visible desktop applications.
```

Then:

```text
Show a structured snapshot of the active window.
```

Only after reads work should you test a harmless UI action.

## A4 — stop

```bash
tp-mcp-stop
```

The old `trycloudflare.com` URL should stop working after the tunnel closes.

---

# Version B — `mcp-proxy` Public Tunnel (`tunnel.gla.ma`)

Upstream `mcp-proxy` supports:

```bash
npx mcp-proxy --port 8080 --tunnel -- <stdio-server>
```

and prints a root URL shaped like:

```text
tunnel established at https://abcdefghij.tunnel.gla.ma
```

For Touchpoint, the Nix helper adds `--server stream` and exposes the MCP endpoint at `/mcp`.

## B1 — start the built-in public tunnel

```bash
tp-mcp-gla-restart
```

Expected shape:

```text
Touchpoint MCP via mcp-proxy Public Tunnel is ready
Tunnel root:     https://abcdefghij.tunnel.gla.ma
ChatGPT MCP URL: https://abcdefghij.tunnel.gla.ma/mcp
```

The hostname will normally be different from the example.

## B2 — smoke test

```bash
tp-mcp-gla-test
```

Print only the MCP URL:

```bash
tp-mcp-gla-url
```

## B3 — connect from ChatGPT

Create another developer MCP/app connection and paste the value from:

```bash
tp-mcp-gla-url
```

Again, use **no authentication** for this temporary developer test.

Test:

```text
List the visible desktop applications.
```

then:

```text
Show a structured snapshot of the active window.
```

## B4 — stop

```bash
tp-mcp-stop
```

---

# Commands

```bash
# Install/update the pinned Touchpoint venv
tp-install

# Touchpoint backend health
tp-diagnostics

# Direct stdio MCP
tp-mcp

# Local HTTP mcp-proxy only (http://127.0.0.1:8081/mcp)
tp-mcp-local

# Cloudflare variant
tp-mcp-cf-restart
tp-mcp-cf-test
tp-mcp-cf-url

# mcp-proxy Public Tunnel variant
tp-mcp-gla-restart
tp-mcp-gla-test
tp-mcp-gla-url

# Stop either public variant
tp-mcp-stop
```

## Runtime state and logs

The proxy/tunnel helpers keep temporary state outside the Nix store at:

```text
~/.local/state/touchpoint-mcp-proxy/
```

Useful logs:

```bash
tail -n 100 ~/.local/state/touchpoint-mcp-proxy/cloudflare-proxy.log
tail -n 100 ~/.local/state/touchpoint-mcp-proxy/cloudflare-tunnel.log
tail -n 100 ~/.local/state/touchpoint-mcp-proxy/gla-proxy.log
```

The npm cache used by `npx mcp-proxy` is also kept there so repeated tests do not need a fresh package download every run.

## Chrome/Electron CDP (optional)

Touchpoint can augment macOS AX with CDP for Chromium/Electron content. The `m1-min` config leaves CDP auto-discovery enabled.

For a Chrome test session:

```bash
open -na "Google Chrome" --args \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/tp-chrome
```

This is optional; native macOS AX works without CDP for normal desktop applications.

## Important MVP warning

Both public variants are anonymous. Anyone who learns the temporary URL can potentially use Touchpoint's MCP tools to inspect and interact with the Mac desktop while the process is running.

For this experiment, keep the URL private and always finish with:

```bash
tp-mcp-stop
```
