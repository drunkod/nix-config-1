# Connect Tududi MCP to a ChatGPT plugin on `m1-min`

This guide documents the tested architecture for connecting the Tududi MCP integration from this repository to ChatGPT developer-mode plugins without exposing the Tududi `tt_...` API token to ChatGPT.

It is written for branch `agent/integrate-tududi-m1-min` and the `m1-min` Apple Silicon profile.

## Short version

Use this path for ChatGPT:

```text
ChatGPT plugin
    |
    | OpenAI Secure MCP Tunnel
    v
OpenAI tunnel-client on the Mac
    |
    | stdio
    v
tududi-mcp-stdio
    |
    | TUDUDI_API_TOKEN loaded from SOPS at runtime
    v
Tududi local data/service
```

Do **not** paste the Tududi `tt_...` token into ChatGPT.

The repository also includes a Cloudflare Quick Tunnel:

```text
ChatGPT -> https://<random>.trycloudflare.com/api/mcp -> Tududi
```

but that endpoint requires `Authorization: Bearer tt_...`. ChatGPT plugins cannot present arbitrary customer API keys, so the Cloudflare Quick Tunnel is **not** the direct authenticated ChatGPT path. It remains useful for testing the remote HTTP MCP endpoint with clients that can set a bearer token, or as the public transport behind a future OAuth 2.1 gateway.

For private developer-mode ChatGPT testing, OpenAI Secure MCP Tunnel is the simplest secure path because it can forward directly to a local stdio MCP server.

## What the current branch already provides

The `m1-min` profile currently enables:

- Tududi on `127.0.0.1:3002`.
- Tududi MCP.
- SOPS-backed Tududi secrets.
- A local stdio MCP wrapper named `tududi-mcp-stdio`.
- The optional `td-mcp-quick-*` Cloudflare Quick Tunnel helpers.

Relevant files:

- `modules/hosts/darwin/m1/default.nix`
- `modules/services/tududi.nix`
- `modules/services/tududi-mcp-quick.nix`
- `secrets/default.yaml`
- `docs/tududi/m1-min.md`

The Tududi module reads the API token from the SOPS runtime secret file and exports it only inside the `tududi-mcp-stdio` wrapper before starting Tududi's MCP server. That is exactly what we want for the OpenAI tunnel: ChatGPT talks MCP over the tunnel, while the Tududi credential stays local to the Mac.

## What the troubleshooting logs established

The setup history matters because the current branch is ahead of the first failed attempt.

The logs showed:

1. The broad Tududi Cloudflare Quick Tunnel was stopped.
2. Tududi remained healthy on loopback.
3. Unauthenticated HTTP MCP correctly returned `401`.
4. SOPS decryption and the local age key worked.
5. Login with the bootstrap administrator succeeded.
6. The first API-key creation attempt returned HTTP `500`.
7. That attempt did not revoke any old key and temporary plaintext material was removed.
8. A later successful branch commit completed credential rotation, created one managed Tududi API token, stored Tududi secrets in `secrets/default.yaml`, enabled `services.tududi.sops`, and passed Nix evaluation and the full `m1-min` system build.

Therefore this guide starts from the current declarative SOPS setup. Do not repeat the bootstrap/token rotation unless you intentionally want to rotate credentials.

## Why the direct Cloudflare URL fails in ChatGPT

The Quick Tunnel helper prints an endpoint like:

```text
https://<random>.trycloudflare.com/api/mcp
```

Tududi expects requests to that endpoint to contain:

```text
Authorization: Bearer tt_...
```

OpenAI's current plugin authentication documentation says authenticated MCP servers should use the MCP OAuth 2.1 authorization flow, and ChatGPT cannot present arbitrary custom API keys supplied by the customer.

So these ChatGPT configurations are not valid for the existing Tududi HTTP MCP endpoint:

- `Authentication: none` — Tududi rejects the request.
- Pasting `tt_...` into the plugin UI — do not do this; ChatGPT does not support arbitrary customer API keys for MCP plugin auth.
- Selecting OAuth against raw Tududi — Tududi's current endpoint does not publish the OAuth protected-resource and authorization-server metadata ChatGPT needs.

For a public HTTPS plugin endpoint you would need an OAuth 2.1-aware MCP gateway in front of Tududi. For private developer-mode use, Secure MCP Tunnel avoids the need to expose the HTTP endpoint at all.

## Prerequisites

You need:

1. The repository checked out on branch `agent/integrate-tududi-m1-min`.
2. The `m1-min` profile activated.
3. Tududi SOPS secrets already materialized successfully.
4. ChatGPT Developer mode available for the target account/workspace.
5. Access to OpenAI Platform tunnel settings.
6. Platform tunnel permissions:
   - `Tunnels Read + Manage` to create or edit a tunnel.
   - `Tunnels Read + Use` to run `tunnel-client` and select the tunnel from ChatGPT.
7. Outbound HTTPS access from the Mac to OpenAI.

OpenAI Platform tunnel permissions and ChatGPT Developer mode are separate permissions.

## Step 1 — activate the current `m1-min` configuration

From the repository:

```bash
cd ~/nix-config
git switch agent/integrate-tududi-m1-min
darwin-rebuild switch --flake .#m1-min
exec zsh -l
```

If you normally use `nh`, the equivalent is:

```bash
nh darwin switch .#m1-min
```

## Step 2 — verify Tududi locally

Check health:

```bash
td-health
```

Expected shape:

```json
{"status":"ok","environment":"production"}
```

The exact JSON may include additional fields such as a timestamp, uptime, or proxy status.

Confirm the MCP wrapper exists:

```bash
command -v tududi-mcp-stdio
```

Do not print or inspect the `tt_...` token itself.

If the wrapper reports that the API token is not configured, first verify the current branch is active and that Home Manager/SOPS activation completed successfully.

## Step 3 — stop the repository Cloudflare Quick Tunnel

For the ChatGPT Secure MCP Tunnel path, the public Cloudflare tunnel is unnecessary.

Stop it if it is running:

```bash
td-mcp-quick-stop
```

This reduces the exposed surface while you configure ChatGPT.

The repository's Quick Tunnel points Cloudflare at the complete local Tududi origin, not only `/api/mcp`, so keeping it stopped is the safer default when it is not needed.

## Step 4 — optionally inspect the local MCP server

OpenAI recommends testing the MCP server before connecting it to ChatGPT.

Start MCP Inspector:

```bash
npx @modelcontextprotocol/inspector@latest
```

In Inspector, configure a stdio server using the command returned by:

```bash
command -v tududi-mcp-stdio
```

Verify that Inspector can initialize the server, list its tools, and execute a harmless read-only call.

Do not copy the Tududi API token into Inspector. The wrapper loads it from the SOPS runtime file itself.

## Step 5 — create an OpenAI Secure MCP Tunnel

Open OpenAI Platform tunnel settings and create a tunnel for this Mac/Tududi development connection.

Recommended name:

```text
tududi-m1-min
```

Associate the tunnel with both:

- the Platform organization that owns/manages the tunnel; and
- the ChatGPT workspace in which you will create the plugin.

Save the returned tunnel ID. It has a form similar to:

```text
tunnel_0123456789abcdef0123456789abcdef
```

Do not commit a control-plane API key to this repository.

## Step 6 — install `tunnel-client`

Use the download from OpenAI Platform tunnel settings or the latest official `openai/tunnel-client` release.

After installation, verify it:

```bash
tunnel-client help quickstart
```

Do not hard-code an old release URL into this runbook; use the current download offered by OpenAI.

## Step 7 — configure `tunnel-client` to use the repo's stdio MCP wrapper

Create a runtime OpenAI API key for `tunnel-client`, then put it only in your current shell or another local secret manager:

```bash
export CONTROL_PLANE_API_KEY='sk-...'
```

Resolve the Tududi MCP command from the activated Home Manager profile:

```bash
TUDUDI_MCP_COMMAND="$(command -v tududi-mcp-stdio)"
printf '%s\n' "$TUDUDI_MCP_COMMAND"
```

Initialize a named tunnel profile:

```bash
tunnel-client init \
  --sample sample_mcp_stdio_local \
  --profile tududi-m1-min \
  --tunnel-id tunnel_0123456789abcdef0123456789abcdef \
  --mcp-command "$TUDUDI_MCP_COMMAND"
```

Replace the example tunnel ID with the one created in OpenAI Platform.

Why use stdio here instead of `http://127.0.0.1:3002/api/mcp`?

- `tududi-mcp-stdio` already loads the Tududi API token from SOPS locally.
- The Tududi `tt_...` credential never has to become ChatGPT plugin configuration.
- Tududi stays private on loopback.
- The repository's Cloudflare public exposure is unnecessary.

## Step 8 — validate the tunnel

Run OpenAI's tunnel diagnostics:

```bash
tunnel-client doctor --profile tududi-m1-min --explain
```

Resolve every error before continuing.

Then run the tunnel:

```bash
tunnel-client run --profile tududi-m1-min
```

Keep this process running while scanning tools or using the plugin in ChatGPT.

If the client exposes its local admin UI, use that loopback-only UI to confirm that the tunnel is healthy, ready, and polling.

## Step 9 — enable ChatGPT Developer mode

In ChatGPT web:

1. Open **Settings**.
2. Open **Security and login**.
3. Enable **Developer mode**.

The exact availability depends on your ChatGPT plan and workspace policy.

For managed workspaces, an administrator may need to grant developer-mode access separately from the Platform tunnel permissions.

## Step 10 — create the ChatGPT plugin connection

Open **ChatGPT Plugins** and create a developer-mode plugin/app:

1. Select the **plus** button.
2. Name it, for example:

   ```text
   Tududi
   ```

3. Description:

   ```text
   Manage personal tasks and projects in the local Tududi instance on m1-min.
   ```

4. Under **Connection**, select **Tunnel**.
5. Select `tududi-m1-min`, or paste its `tunnel_id` if necessary.
6. Create the connection.
7. Review the tools and metadata ChatGPT discovers.

Do not select a public Server URL containing the Cloudflare `trycloudflare.com` endpoint for this authenticated setup.

## Step 11 — test in ChatGPT

Start a new chat and add the Tududi plugin from the tools menu.

Begin with read-only prompts, for example:

```text
List my current Tududi projects.
```

Then test a narrow lookup:

```text
Show my open Tududi tasks due today.
```

Only after reads work reliably should you test a write action, for example creating a harmless temporary task. Review and confirm the action when ChatGPT asks.

Afterward, remove the test task if appropriate.

## Step 12 — normal startup procedure

After the one-time setup, the typical sequence is:

```bash
cd ~/nix-config
git switch agent/integrate-tududi-m1-min

td-health

export CONTROL_PLANE_API_KEY='sk-...'
tunnel-client doctor --profile tududi-m1-min --explain
tunnel-client run --profile tududi-m1-min
```

Then open ChatGPT and enable/select the Tududi plugin for the conversation.

Keep the OpenAI control-plane key in a local secret manager rather than shell history if you use this regularly.

## Repository Cloudflare Quick Tunnel commands

The repo's existing public Quick Tunnel is still useful for diagnostics and for MCP clients that can provide Tududi's bearer token themselves.

Start or replace it:

```bash
td-mcp-quick-restart
```

Test it:

```bash
td-mcp-quick-test
```

Print the current remote MCP URL:

```bash
td-mcp-quick-url
```

Stop it:

```bash
td-mcp-quick-stop
```

Important properties of this helper:

- It creates a random `*.trycloudflare.com` hostname.
- The hostname changes when the Quick Tunnel is replaced.
- It probes `/api/health` until the public hostname is stable.
- When a SOPS API token is configured, the helper tests authenticated MCP status.
- It validates the saved PID before killing a process, reducing stale-PID risk.
- It publishes the whole Tududi HTTP origin, not only MCP.

### Can the Cloudflare URL be used by a ChatGPT plugin?

Not directly with the current Tududi authentication model.

To make a public Cloudflare path suitable for an authenticated ChatGPT plugin, place an OAuth 2.1-capable MCP gateway in front of Tududi. The gateway must implement the MCP authorization requirements expected by ChatGPT, including protected-resource metadata, authorization-server discovery, authorization-code flow with PKCE, and access-token verification. The gateway can keep the Tududi `tt_...` token server-side and translate authorized MCP requests to Tududi.

Until that gateway exists, use OpenAI Secure MCP Tunnel for ChatGPT and keep `td-mcp-quick-*` for diagnostics or other token-capable clients.

## Troubleshooting

### `tududi-mcp-stdio` says the API token is not configured

Verify the current branch and rebuild:

```bash
git branch --show-current
darwin-rebuild switch --flake .#m1-min
```

Then verify Tududi health:

```bash
td-health
```

Do not print `secrets/default.yaml` decrypted output into a terminal transcript or chat.

### `tunnel-client doctor` cannot start the MCP command

Resolve the command again:

```bash
command -v tududi-mcp-stdio
```

If the path changed after a rebuild, recreate or update the tunnel-client profile so it points at the current Home Manager executable.

### The tunnel does not appear in ChatGPT

Check both:

1. The tunnel is associated with the target ChatGPT workspace, not only the Platform organization.
2. Your Platform role includes `Tunnels Read + Use`.

Tunnel permissions and ChatGPT Developer mode are separate.

### ChatGPT can see the tunnel but tool discovery fails

Confirm the local client is still running:

```bash
tunnel-client doctor --profile tududi-m1-min --explain
```

Then restart:

```bash
tunnel-client run --profile tududi-m1-min
```

Also verify:

```bash
td-health
```

### Direct `trycloudflare.com/api/mcp` setup returns auth errors

That is expected if ChatGPT is trying to call raw Tududi. The endpoint requires Tududi's custom `tt_...` bearer token, and ChatGPT plugins cannot be configured to present arbitrary customer API keys.

Use the Secure MCP Tunnel + stdio path in this guide, or add a standards-compliant OAuth gateway before attempting the public URL path.

### Creating a Tududi API key returns HTTP 500

The troubleshooting session hit this once during the first credential-rotation attempt. The safe behavior was to stop, inspect the local Tududi error log, and avoid revoking any existing key or exposing plaintext secrets.

The current branch already contains the successfully completed SOPS setup, so do not retry API-key creation unless you are intentionally rotating the token.

For a deliberate rotation, use the Tududi UI/API flow supported by the installed Tududi version and inspect:

```text
~/.local/state/tududi/stderr.log
```

for server-side errors. Never paste a newly generated `tt_...` token into ChatGPT.

## Public plugin publication is different

OpenAI Secure MCP Tunnel is intended for private MCP connectivity and developer-mode testing. It is not a replacement for a stable public HTTPS endpoint when publishing a public plugin.

For public distribution, provide a stable public MCP endpoint and implement the authentication model required by OpenAI. For authenticated user-specific data or write actions, that means an OAuth 2.1 flow compatible with the MCP authorization specification.

## Security checklist

Before considering the setup complete:

- [ ] `td-health` succeeds locally.
- [ ] Tududi secrets are managed through SOPS.
- [ ] The Tududi `tt_...` token has never been pasted into ChatGPT.
- [ ] `td-mcp-quick-stop` has stopped the broad Cloudflare Quick Tunnel unless it is intentionally needed.
- [ ] `tunnel-client doctor --profile tududi-m1-min --explain` passes.
- [ ] The OpenAI tunnel is associated with the correct Platform organization and ChatGPT workspace.
- [ ] The ChatGPT operator has `Tunnels Read + Use`.
- [ ] Developer mode is enabled for the ChatGPT account/workspace.
- [ ] Read-only Tududi tools work before any write actions are tested.
- [ ] Control-plane API keys are stored outside the repository and are not committed.

## References

Repository:

- [`m1-min` Tududi guide](./m1-min.md)
- [`modules/services/tududi.nix`](../../modules/services/tududi.nix)
- [`modules/services/tududi-mcp-quick.nix`](../../modules/services/tududi-mcp-quick.nix)
- [`modules/hosts/darwin/m1/default.nix`](../../modules/hosts/darwin/m1/default.nix)
- [`SOPS.md`](../../SOPS.md)

OpenAI:

- Secure MCP Tunnel: <https://developers.openai.com/api/docs/guides/secure-mcp-tunnels>
- Connect and test your plugin: <https://developers.openai.com/plugins/deploy/connect-chatgpt>
- Plugin authentication: <https://developers.openai.com/plugins/build/auth>
