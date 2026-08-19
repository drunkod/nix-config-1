# Tududi MCP Proxy via Cloudflare Quick Tunnel

Use this guide when you specifically want the tested `mcp-proxy` bridge exposed through a temporary `*.trycloudflare.com` URL.

For the simplest public test, use [the `mcp-proxy` Public Tunnel guide](mcp-proxy-public-tunnel.md) instead.

This is an intentionally unauthenticated MVP path.

## Flow

```text
ChatGPT
  -> https://<generated>.trycloudflare.com/mcp
  -> cloudflared Quick Tunnel
  -> 127.0.0.1:8080/mcp
  -> mcp-proxy
  -> tududi-mcp-stdio
  -> Tududi
```

`tududi-mcp-stdio` loads the Tududi API token from SOPS locally. Do not pass the `tt_...` token to ChatGPT, `mcp-proxy`, or Cloudflare.

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
command -v tududi-mcp-proxy-local
command -v tududi-mcp-stdio
command -v cloudflared
```

## 2. Start the local MCP bridge

Terminal 1:

```bash
tududi-mcp-proxy-local
```

Equivalent command:

```bash
npx --yes mcp-proxy \
  --port 8080 \
  --stateless \
  -- \
  tududi-mcp-stdio
```

Expected output includes the Tududi stdio server starting, authentication succeeding, tools loading, and `mcp-proxy` listening on port `8080`.

## 3. Test locally

Terminal 2:

```bash
curl --silent --show-error --max-time 20 \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"cloudflare-local-test","version":"0.1"}}}' \
  http://127.0.0.1:8080/mcp
```

Continue only after this returns an MCP `initialize` result.

## 4. Start the Cloudflare Quick Tunnel

In Terminal 2:

```bash
cloudflared tunnel \
  --protocol http2 \
  --url http://127.0.0.1:8080
```

Using `--protocol http2` avoids depending on outbound QUIC. This matched the successful test environment where HTTP/2 connectivity worked even when QUIC checks failed.

Cloudflare prints a URL similar to:

```text
https://random-words.trycloudflare.com
```

Your MCP URL is:

```text
https://random-words.trycloudflare.com/mcp
```

## 5. Wait for the public hostname and test it

A newly-created Quick Tunnel hostname can take a short time to become reachable. Do not configure ChatGPT until the public `initialize` succeeds.

Set the generated URL:

```bash
MCP_URL='https://random-words.trycloudflare.com/mcp'
```

Then retry the same MCP probe for up to about one minute:

```bash
for attempt in {1..12}; do
  if curl --fail --silent --show-error --max-time 20 \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"cloudflare-public-test","version":"0.1"}}}' \
    "$MCP_URL"; then
    break
  fi
  sleep 5
done
```

The current setup was tested successfully through Cloudflare after earlier attempts experienced temporary hostname/DNS publication delays.

## 6. Add it to ChatGPT

Create a developer MCP connection using the generated `/mcp` URL and choose no authentication for this MVP.

Start with read-only calls such as:

```text
List my Tududi projects.
```

```text
Show my open Tududi tasks.
```

## 7. Stop the test

Stop `cloudflared` with `Ctrl-C`, then stop `tududi-mcp-proxy-local` with `Ctrl-C`.

Confirm the local bridge is closed:

```bash
curl --silent --max-time 2 http://127.0.0.1:8080/mcp || true
```

## Troubleshooting

### The hostname is printed but does not resolve

Wait briefly and retry. If it still fails, stop `cloudflared` and create a fresh Quick Tunnel. The local `/mcp` probe should continue to work throughout this test.

### QUIC fails

Use the documented `--protocol http2` command. The tested network reported failed QUIC connectivity but successful HTTP/2 tunnel registration.

### Streaming limitations

Cloudflare documents Quick Tunnels as development-only and does not support long-lived Server-Sent Events. The tested MCP `initialize` call can still return finite SSE-style framing through `mcp-proxy`, but do not treat Quick Tunnel as a production streaming transport.

For a stable hostname and full tunnel feature set, move to a named Cloudflare Tunnel after the MVP.

## Security

The public URL has no additional authentication. Anyone who has the URL can reach the exposed MCP tools. Stop both processes immediately after testing.
