# Fast Repo Harness MCP Quick Tunnel workflow

This is the short operator path for the `m1-min` Repo Harness coding MCP when a
stable Cloudflare domain is not available.

It complements the named-tunnel setup in
[`repo-harness-mcp-coding-m1-min.md`](repo-harness-mcp-coding-m1-min.md).
Quick Tunnels are ephemeral: every restart can produce a new
`*.trycloudflare.com` hostname, so ChatGPT must be pointed at the new `/mcp`
URL and authorized again after the hostname changes.

## One-time rebuild

PR #9 enables `services.repo-harness-mcp-quick` on `m1-min`.

```bash
cd ~/nix-config
sudo darwin-rebuild switch --flake .#m1-min
exec zsh
```

The module installs these helpers:

| Command | Purpose |
|---|---|
| `rh-mcp-quick-restart` | Replace the Quick Tunnel, bootstrap Repo Harness with the new URL, restart MCP, and require a green live doctor |
| `rh-mcp-quick-test` | Check local health, tunnel process/registration, public health, and live doctor |
| `rh-mcp-quick-url` | Print the current ChatGPT MCP URL |
| `rh-mcp-auth` | Complete the ChatGPT OAuth browser transaction from a fresh `/authorize?...` URL in the macOS clipboard |

Runtime state is private and local:

```text
~/.local/state/repo-harness-mcp-quick/
├── cloudflared.log
├── cloudflared.pid
└── public-url
```

No OAuth passphrase, bearer token, or Cloudflare credential is written there.

## Restart everything with one command

```bash
rh-mcp-quick-restart
```

The helper performs the sequence that was proven manually during runtime
validation:

1. restore the launchd `PATH` needed by the Bun-based Repo Harness launcher;
2. require local `127.0.0.1:8765/health`, restarting MCP first if necessary;
3. stop the previous helper-owned Quick Tunnel and any matching manually-started
   `cloudflared tunnel --url http://127.0.0.1:8765` process;
4. start a fresh tunnel with `--protocol http2`;
5. wait for the generated `https://*.trycloudflare.com` URL;
6. require `Registered tunnel connection ... protocol=http2`;
7. probe public `/health` before bootstrap, accepting only `200` or the expected
   stale-origin `421`;
8. run `repo-harness-mcp-bootstrap --endpoint <new-url>/mcp`;
9. restart Repo Harness;
10. require public health, local OAuth discovery, and `mcp_ready` live doctor.

Successful output ends with the new public origin and ChatGPT MCP URL.

Get only the current MCP URL later with:

```bash
rh-mcp-quick-url
```

## Fast health test

```bash
rh-mcp-quick-test
```

The command fails closed unless all of these hold:

```text
local MCP health                   PASS
cloudflared PID alive              PASS
HTTP/2 registration in tunnel log  PASS
public /health                     PASS
public_origin matches saved URL    PASS
Repo Harness live doctor           mcp_ready
```

Useful raw log:

```bash
tail -n 100 ~/.local/state/repo-harness-mcp-quick/cloudflared.log
```

## Update ChatGPT after a Quick Tunnel restart

In ChatGPT Developer mode, edit/recreate the custom MCP app with the value from:

```bash
rh-mcp-quick-url
```

Keep authentication set to OAuth.

A Quick Tunnel hostname change also changes Repo Harness `public_origin`; an old
ChatGPT app URL must not be reused.

## Complete OAuth with `rh-mcp-auth`

The Repo Harness coding server permits OAuth POSTs with the ChatGPT origin. A
browser-hosted authorization form on the Quick Tunnel origin can therefore fail
with:

```json
{"error":"origin_not_allowed"}
```

The helper preserves that fail-closed origin policy instead of weakening it.
It submits the fresh OAuth transaction with:

```text
Origin: https://chatgpt.com
```

and never prints the local passphrase.

Use this exact sequence:

1. In ChatGPT click **Sign in with Repo Harness Coding**.
2. When the Repo Harness passphrase page opens, do **not** submit the browser
   form.
3. Press `Cmd+L`, then `Cmd+C` to copy the entire fresh
   `https://<quick-host>/authorize?...` URL.
4. Run:

   ```bash
   rh-mcp-auth
   ```

The helper:

- reads the authorization URL from `pbpaste`;
- immediately clears the clipboard;
- verifies that the authorization host equals the current Repo Harness
  `public_origin`;
- requires authorization-code flow with PKCE `S256`;
- requires the callback host to be `chatgpt.com`;
- verifies the OAuth `resource`, when present, matches the current `/mcp` URL;
- reads `~/.repo-harness/mcp.oauth.json` locally without printing its
  passphrase;
- POSTs `/authorize` with `Origin: https://chatgpt.com`;
- requires a `302` or `303` redirect back to `https://chatgpt.com`;
- opens the validated ChatGPT callback with macOS `open`.

Expected terminal output:

```text
Authorization HTTP status: 302
OAuth accepted; opening ChatGPT callback
```

Never paste the fresh authorization URL, callback URL, passphrase,
authorization code, or tokens into chat or commit them.

## ChatGPT canary

After OAuth completes, start a new ChatGPT conversation and use a read-only
first request:

```text
Use Repo Harness Coding and call harness_status.
Do not call any other tool.
Do not modify anything and do not run shell commands.
```

Require a visible `Called tool` event. A successful `rh-mcp-doctor` proves the
transport and schema but does not by itself prove that ChatGPT invoked the MCP
app.

Only after the read-only canary succeeds should `apply_patch` or `exec_command`
be tested.

## Why HTTP/2 is forced

The validated network path can carry Cloudflare Tunnel TCP/7844 but not QUIC.
The VPS routing used during validation sends incoming VMess TCP/7844 traffic to
`direct-out` instead of WARP, and V2Ray TLS destination sniffing is disabled.
With that path, Cloudflare's TCP connectivity checks pass and Quick Tunnel
registration succeeds over HTTP/2.

Do not remove `--protocol http2` from the fast helper unless the underlying
network path has been revalidated for QUIC.
