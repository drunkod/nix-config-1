# Fast Repo Harness MCP Quick Tunnel workflow

This is the short operator path for the `m1-min` Repo Harness `coding` MCP when
a stable Cloudflare hostname is not available.

It complements the named-tunnel setup in
[`repo-harness-mcp-coding-m1-min.md`](repo-harness-mcp-coding-m1-min.md).
Quick Tunnel hostnames are ephemeral, so a tunnel replacement changes the
ChatGPT MCP URL and requires reconnecting/reauthorizing the ChatGPT app.

## Runtime-proven behavior

The target Mac validation established these facts:

- Repo Harness listens only on `127.0.0.1:8765`;
- `cloudflared` must use `--protocol http2` on the validated phone/VPS path;
- Cloudflare TCP connectivity on port 7844 passes even though QUIC does not;
- the reliable manual tunnel flow waits roughly 20 seconds after creating the
  tunnel before the first lookup of the generated `*.trycloudflare.com` name;
- after Repo Harness is bootstrapped to the new `/mcp` URL, public `/health`,
  OAuth discovery, DCR + PKCE, MCP initialize, and the exact 24-tool schema pass;
- the browser authorization form can hit `origin_not_allowed`, while the
  validated OAuth helper succeeds by posting the same fresh transaction with
  `Origin: https://chatgpt.com`;
- a real ChatGPT `harness_status` call has completed successfully against the
  configured `coding` profile.

The Nix helper mirrors that proven sequence rather than querying a newly-issued
Quick Tunnel hostname immediately.

## One-time validation and activation

```bash
cd ~/nix-config
nix flake check -L --show-trace
sudo darwin-rebuild build --flake .#m1-min

nix build \
  .#darwinConfigurations.m1-min.config.home-manager.users.test.home.activationPackage
./result/activate
exec zsh
```

The Home Manager module installs four direct store-path aliases:

| Command | Purpose |
|---|---|
| `rh-mcp-quick-restart` | replace the Quick Tunnel, update Repo Harness, restart MCP, and require a green live doctor |
| `rh-mcp-quick-test` | verify the currently configured public MCP endpoint and live doctor |
| `rh-mcp-quick-url` | print the currently configured ChatGPT MCP URL |
| `rh-mcp-auth` | complete a fresh ChatGPT OAuth transaction from the macOS clipboard |

The aliases intentionally point at generated `/nix/store/.../bin/...` paths so
they remain available after standalone Home Manager activation even when the
nix-darwin per-user profile has not been switched yet.

## Restart MCP + Quick Tunnel

```bash
rh-mcp-quick-restart
```

The helper performs this sequence:

1. restore the launchd `PATH` required by the Bun-based Repo Harness launcher;
2. require local `127.0.0.1:8765/health`, restarting MCP first if needed;
3. stop the previous helper-owned tunnel and a matching manual
   `cloudflared tunnel --url http://127.0.0.1:8765` process;
4. start a fresh Quick Tunnel with `--protocol http2`;
5. wait for both the generated URL and
   `Registered tunnel connection ... protocol=http2`;
6. wait **20 seconds without querying the new public hostname**;
7. begin public readiness checks, accepting `421` before Repo Harness learns
   the new origin and `200` when it is already configured;
8. require consecutive stable public responses;
9. run `repo-harness-mcp-bootstrap --endpoint <new-url>/mcp`;
10. restore launchd `PATH` and restart Repo Harness;
11. require public JSON health with the new `public_origin`;
12. require local OAuth discovery and a live doctor with every layer green.

The `m1-min` timing is explicit:

```nix
services.repo-harness-mcp-quick = {
  enable = true;
  waitSeconds = 45;
  publishGraceSeconds = 20;
  publicReadySeconds = 120;
  retryIntervalSeconds = 5;
  probeCount = 5;
};
```

Successful output ends with:

```text
Repo Harness Quick Tunnel ready
Public origin: https://<generated>.trycloudflare.com
ChatGPT MCP:   https://<generated>.trycloudflare.com/mcp
```

Runtime state is private and local:

```text
~/.local/state/repo-harness-mcp-quick/
├── cloudflared.log
├── cloudflared.pid
└── public-url
```

On a failed helper-owned startup, the child is stopped and failed PID/URL state
is removed while `cloudflared.log` is preserved for diagnosis.

## Test the currently configured endpoint

```bash
rh-mcp-quick-test
```

The test intentionally reads the authoritative endpoint from:

```text
~/.repo-harness/mcp.local.json
```

That means it also works after the equivalent manual tunnel/bootstrap sequence;
it does not require the tunnel to have been created by `rh-mcp-quick-restart`.

It requires:

```text
local MCP health             PASS
public /health               PASS
public_origin matches URL    PASS
live doctor                  mcp_ready
all doctor layers            true
```

Print the current ChatGPT MCP URL with:

```bash
rh-mcp-quick-url
```

This also prefers `~/.repo-harness/mcp.local.json`, so it reports the active
endpoint even when the tunnel was created manually.

## Complete ChatGPT OAuth

After a hostname change:

1. update the ChatGPT app/server URL using `rh-mcp-quick-url`;
2. keep authentication set to OAuth;
3. click **Sign in with Repo Harness Coding**;
4. when the Repo Harness `/authorize?...` page opens, do **not** submit the
   browser form;
5. press `Cmd+L`, then `Cmd+C` to copy the entire fresh authorization URL;
6. run:

```bash
rh-mcp-auth
```

A wrong or stale clipboard fails closed, for example:

```text
STOP: clipboard is not the fresh Repo Harness /authorize URL
```

A successful transaction prints:

```text
Authorization HTTP status: 302
OAuth accepted; opening ChatGPT callback
```

The helper:

- captures and immediately clears the clipboard;
- requires the authorization hostname to equal current Repo Harness
  `public_origin`;
- requires authorization-code flow with PKCE `S256`;
- requires the callback host to be `chatgpt.com`;
- validates the OAuth `resource` against the current `/mcp` URL when present;
- reads `~/.repo-harness/mcp.oauth.json` locally without printing the passphrase;
- posts `/authorize` with `Origin: https://chatgpt.com`;
- requires a `302` or `303` redirect;
- validates and opens only a `https://chatgpt.com` callback.

Never paste the fresh authorization URL, callback URL, passphrase,
authorization code, or tokens into chat or commit them.

## ChatGPT canary

After OAuth completes, start with a read-only tool call:

```text
Use Repo Harness Coding and call harness_status.
Do not call any other tool.
Do not modify anything and do not run shell commands.
```

Require a visible `Called tool` event. The validated response identifies the
repo as adopted and the profile as `coding`.

Then test:

```text
Use Repo Harness Coding and call harness_doctor.
Do not call any other tool.
Do not modify anything and do not run shell commands.
```

Only after these read-only canaries succeed should `apply_patch` or
`exec_command` be exercised.

## Manual fallback

If the helper itself is under investigation, the runtime-proven fallback is:

```bash
pkill -f 'cloudflared tunnel.*127.0.0.1:8765' || true
rm -f /tmp/repo-harness-quick-tunnel.log

nohup cloudflared tunnel \
  --protocol http2 \
  --loglevel info \
  --url http://127.0.0.1:8765 \
  > /tmp/repo-harness-quick-tunnel.log 2>&1 &

sleep 20

QUICK_URL="$(grep -o 'https://[^ ]*trycloudflare.com' \
  /tmp/repo-harness-quick-tunnel.log | head -1)"

repo-harness-mcp-bootstrap \
  --repo "$HOME/nix-config" \
  --endpoint "$QUICK_URL/mcp"

launchctl setenv PATH \
  "$HOME/.bun/bin:/etc/profiles/per-user/test/bin:/usr/bin:/bin:/usr/sbin:/sbin"

repo-harness-mcp-restart
sleep 3
curl -fsS "$QUICK_URL/health" | jq
repo-harness-mcp-health
repo-harness-mcp-doctor
```

The fallback intentionally retains the same 20-second quiet publication delay
that succeeded during target-Mac validation.
