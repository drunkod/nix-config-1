# Tududi MCP Proxy via mcp-proxy Public Tunnel

This guide launches the tested `mcp-proxy --tunnel` variant. `mcp-proxy` creates the public `*.tunnel.gla.ma` endpoint itself, so a separate `cloudflared` process is not needed.

This is an MVP test path. The public MCP endpoint has no additional authentication layer.

## Flow

```text
ChatGPT
  -> https://<generated>.tunnel.gla.ma/mcp
  -> mcp-proxy Public Tunnel
  -> mcp-proxy local bridge
  -> tududi-mcp-stdio
  -> Tududi
```

`tududi-mcp-stdio` continues to load the Tududi API token from the existing SOPS configuration. Do not pass the `tt_...` token to the public tunnel.

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

Verify the wrapper is installed:

```bash
command -v tududi-mcp-proxy-public
command -v tududi-mcp-stdio
```

## 3. Verify Tududi

```bash
td-health
```

Expected result includes:

```json
{"status":"ok"}
```

## 4. Start the Public Tunnel

Run:

```bash
tududi-mcp-proxy-public
```

The wrapper runs the equivalent of:

```bash
npx --yes mcp-proxy \
  --port 8080 \
  --tunnel \
  --stateless \
  -- \
  tududi-mcp-stdio
```

Expected output includes lines similar to:

```text
Tududi MCP server running on stdio
Authenticated as: ...
Available tools: ...
starting server on port 8080
establishing tunnel via tunnel.gla.ma
tunnel established at https://abcdefghij.tunnel.gla.ma
```

The actual hostname is generated at runtime. The example hostname `https://abcdefghij.tunnel.gla.ma` is only a placeholder.

Leave this terminal running.

## 5. Build the MCP URL

Append `/mcp` to the generated tunnel URL.

Example:

```text
https://abcdefghij.tunnel.gla.ma/mcp
```

## 6. Test the public MCP endpoint

Open a second terminal and set the generated URL:

```bash
MCP_URL='https://abcdefghij.tunnel.gla.ma/mcp'
```

Then send an MCP initialize request:

```bash
curl --silent --show-error --max-time 30 \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"public-tunnel-test","version":"0.1"}}}' \
  "$MCP_URL"
```

A successful response contains an MCP `initialize` result with Tududi server information.

The tested implementation may return the response in SSE framing such as:

```text
event: message
data: {"result":{...},"jsonrpc":"2.0","id":1}
```

That is expected for this `mcp-proxy` setup.

## 7. Add it to ChatGPT

Use the generated URL with `/mcp`:

```text
https://abcdefghij.tunnel.gla.ma/mcp
```

For this MVP test, use the unauthenticated/no-auth connection option.

Start with a read request:

```text
List my Tududi projects.
```

Then:

```text
Show my open Tududi tasks.
```

## 8. Stop the test

Press `Ctrl-C` in the terminal running `tududi-mcp-proxy-public`.

Confirm the local bridge stopped:

```bash
curl --silent --max-time 2 http://127.0.0.1:8080/mcp || true
```

The generated `tunnel.gla.ma` URL is temporary and should stop working after the proxy process exits.

Because this is an intentionally unsafe MVP, do not leave the public tunnel running after testing.
