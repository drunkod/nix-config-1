# Tududi MCP Proxy via Cloudflare Quick Tunnel

This guide launches the tested `mcp-proxy` local bridge and exposes it through a temporary `*.trycloudflare.com` URL.

This is an MVP test path. The public MCP endpoint has no additional authentication layer.

## Flow

```text
ChatGPT
  -> https://<random>.trycloudflare.com/mcp
  -> cloudflared Quick Tunnel
  -> 127.0.0.1:8080/mcp
  -> mcp-proxy
  -> tududi-mcp-stdio
  -> Tududi
```

`tududi-mcp-stdio` continues to load the Tududi API token from the existing SOPS configuration. Do not pass the `tt_...` token to `mcp-proxy` or Cloudflare.

## 1. Switch to the MVP branch

```bash
cd ~/nix-config
git fetch origin
git switch agent/tududi-mcp-proxy-mvp
git pull --ff-only
```

## 2. Rebuild `m1-min`

```bash
darwin-rebuild switch --flake .#m1-min
exec zsh -l
```

The profile installs the wrapper from `modules/services/tududi-mcp-proxy.nix`.

Verify it is available:

```bash
command -v tududi-mcp-proxy-local
command -v tududi-mcp-stdio
command -v cloudflared
```

## 3. Verify Tududi

```bash
td-health
```

Expected result includes:

```json
{"status":"ok"}
```

## 4. Start `mcp-proxy`

Open terminal 1:

```bash
tududi-mcp-proxy-local
```

The wrapper runs the equivalent of:

```bash
npx --yes mcp-proxy \
  --port 8080 \
  --stateless \
  -- \
  tududi-mcp-stdio
```

Expected log lines include:

```text
Tududi MCP server running on stdio
Authenticated as: ...
Available tools: ...
starting server on port 8080
```

Leave terminal 1 running.

## 5. Test the local MCP endpoint

In terminal 2:

```bash
curl --silent --show-error --max-time 20 \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"cloudflare-test","version":"0.1"}}}' \
  http://127.0.0.1:8080/mcp
```

A successful response contains an MCP `initialize` result and Tududi server information.

## 6. Start the Cloudflare Quick Tunnel

Still in terminal 2:

```bash
cloudflared tunnel --url http://127.0.0.1:8080
```

Wait for a generated URL similar to:

```text
https://random-words.trycloudflare.com
```

The MCP URL is:

```text
https://random-words.trycloudflare.com/mcp
```

## 7. Test through Cloudflare

Replace the hostname below with the URL printed by `cloudflared`:

```bash
MCP_URL='https://random-words.trycloudflare.com/mcp'

curl --silent --show-error --max-time 30 \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"cloudflare-public-test","version":"0.1"}}}' \
  "$MCP_URL"
```

If this returns the Tududi MCP initialize response, the tunnel is ready.

## 8. Add it to ChatGPT

Use the generated MCP URL:

```text
https://random-words.trycloudflare.com/mcp
```

For this MVP test, use the unauthenticated/no-auth connection option.

Test with a read request first, for example:

```text
List my Tududi projects.
```

Then try:

```text
Show my open Tududi tasks.
```

## 9. Stop the test

Press `Ctrl-C` in the `cloudflared` terminal, then press `Ctrl-C` in the `tududi-mcp-proxy-local` terminal.

Confirm port 8080 is closed:

```bash
curl --silent --max-time 2 http://127.0.0.1:8080/mcp || true
```

Because this is an intentionally unsafe MVP, do not leave the temporary public endpoint running when you are finished testing.
