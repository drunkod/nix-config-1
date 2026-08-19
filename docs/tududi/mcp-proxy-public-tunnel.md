# Tududi MCP Proxy via `mcp-proxy` Public Tunnel

This is the simplest tested public MVP path for ChatGPT. `mcp-proxy` starts the local HTTP bridge and creates the temporary `*.tunnel.gla.ma` public tunnel in one process.

This path is intentionally unauthenticated.

## Flow

```text
ChatGPT
  -> https://<generated>.tunnel.gla.ma/mcp
  -> mcp-proxy Public Tunnel
  -> mcp-proxy local bridge
  -> tududi-mcp-stdio
  -> Tududi
```

`tududi-mcp-stdio` loads the Tududi API token from SOPS locally. Do not pass the `tt_...` token to ChatGPT or the public tunnel.

## 1. Activate the tested profile

```bash
cd ~/nix-config
git switch agent/tududi-mcp-proxy-mvp
git pull --ff-only
sudo darwin-rebuild switch --flake .#m1-min
exec zsh -l
```

Verify the commands:

```bash
td-health
command -v tududi-mcp-proxy-public
command -v tududi-mcp-stdio
```

## 2. Start the public tunnel

```bash
tududi-mcp-proxy-public
```

Equivalent command:

```bash
npx --yes mcp-proxy \
  --port 8080 \
  --tunnel \
  --stateless \
  -- \
  tududi-mcp-stdio
```

Expected output includes:

```text
Tududi MCP server running on stdio
Authenticated as: ...
Available tools: ...
starting server on port 8080
establishing tunnel via tunnel.gla.ma
tunnel established at https://<generated>.tunnel.gla.ma
```

The hostname is generated at runtime. Leave this terminal running.

## 3. Test the public MCP endpoint

Append `/mcp` to the generated URL:

```bash
MCP_URL='https://<generated>.tunnel.gla.ma/mcp'
```

Then send an MCP `initialize` request:

```bash
curl --silent --show-error --max-time 30 \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"public-tunnel-test","version":"0.1"}}}' \
  "$MCP_URL"
```

A successful response contains Tududi server information. The tested setup returned finite SSE-style framing such as:

```text
event: message
data: {"result":{...},"jsonrpc":"2.0","id":1}
```

## 4. Add it to ChatGPT

Create a developer MCP connection using the generated `/mcp` URL and choose no authentication for this MVP.

Start with read-only calls:

```text
List my Tududi projects.
```

```text
Show my open Tududi tasks.
```

## 5. Stop the test

Press `Ctrl-C` in the terminal running `tududi-mcp-proxy-public`.

Confirm the local bridge is closed:

```bash
curl --silent --max-time 2 http://127.0.0.1:8080/mcp || true
```

The generated `tunnel.gla.ma` URL should stop forwarding after the process exits.

## Security

The public URL has no additional authentication. Anyone who obtains it can reach the exposed Tududi MCP tools, including write tools. Use this only for short development tests.
