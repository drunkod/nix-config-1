# Fast ChatGPT + Tududi MVP through TryCloudflare

This is a deliberately **non-secure developer test** for connecting ChatGPT directly to Tududi MCP through a temporary `*.trycloudflare.com` URL.

It is intended only to prove the transport and tool discovery quickly on branch `agent/integrate-tududi-m1-min`.

## What it does

```text
ChatGPT
  |
  | public HTTPS, no authentication
  v
https://<random>.trycloudflare.com/api/mcp
  |
  | Cloudflare Quick Tunnel
  v
127.0.0.1:3003
  |
  | anonymous stateless MCP gateway
  | JSON responses (no long-lived SSE)
  v
Tududi MCP tool registry
  |
  | local tt_ API token loaded from SOPS
  v
Your Tududi user/data
```

The temporary gateway uses Tududi's existing MCP tool registry directly. It resolves your Tududi user from the SOPS-managed API token, but it does **not** authenticate incoming requests.

## Important warning

While this test is running, **anyone who gets the random TryCloudflare URL can call the exposed Tududi MCP tools, including write tools**.

Treat the URL like a temporary secret. Do not post it publicly. Stop the helper as soon as the test is finished:

```bash
td-chatgpt-quick-stop
```

Do not use this setup for production or long-running access.

## Why this helper exists

The normal `td-mcp-quick-*` helper exposes Tududi's authenticated HTTP MCP endpoint, which expects:

```text
Authorization: Bearer tt_...
```

ChatGPT cannot be configured with that custom Tududi API key for an authenticated plugin connection.

For this MVP, the new `td-chatgpt-quick-*` helper removes authentication at the public MCP layer and uses the existing SOPS token only on the Mac to select the Tududi user.

It also forces JSON request/response mode because Cloudflare Quick Tunnels are a development feature and do not support long-lived SSE streams.

## Step 1 — update and rebuild `m1-min`

```bash
cd ~/nix-config
git fetch origin
git switch agent/integrate-tududi-m1-min
git pull --ff-only

darwin-rebuild switch --flake .#m1-min
exec zsh -l
```

If you normally use `nh`:

```bash
nh darwin switch .#m1-min
exec zsh -l
```

## Step 2 — verify Tududi

```bash
td-health
```

You should get a healthy JSON response.

## Step 3 — start the anonymous MVP + Quick Tunnel

```bash
td-chatgpt-quick-restart
```

The helper:

1. verifies/restarts Tududi if needed;
2. starts the local anonymous MCP gateway on `127.0.0.1:3003`;
3. starts `cloudflared tunnel --url http://127.0.0.1:3003`;
4. waits for a random `trycloudflare.com` hostname;
5. probes the public health endpoint; and
6. prints the ChatGPT MCP URL.

Expected final output looks like:

```text
Tududi ChatGPT Quick MVP ready
ChatGPT MCP URL: https://random-words.trycloudflare.com/api/mcp
Health:          https://random-words.trycloudflare.com/api/health

WARNING: NO AUTHENTICATION. Anyone with this URL can use your Tududi MCP tools.
```

## Step 4 — run the built-in smoke test

```bash
td-chatgpt-quick-test
```

This checks:

- public gateway health;
- anonymous MCP status; and
- a real MCP `initialize` request through TryCloudflare.

The command should end with:

```text
MVP test passed
```

If this step fails, do not configure ChatGPT yet.

## Step 5 — print the MCP URL

```bash
td-chatgpt-quick-url
```

Example:

```text
https://random-words.trycloudflare.com/api/mcp
```

Each restart creates a new hostname, so always use the latest value.

## Step 6 — enable ChatGPT Developer mode

In ChatGPT:

1. Open **Settings**.
2. Select **Security and login**.
3. Enable **Developer mode**.

Availability can depend on your account/workspace policy.

## Step 7 — add the public MCP server

Open **ChatGPT Plugins** and create a developer connection:

1. Select the **plus** button.
2. Name it something like `Tududi MVP`.
3. Use a description such as `Temporary local Tududi MCP test through TryCloudflare`.
4. Under **Connection**, choose the public MCP server URL option.
5. Paste the exact URL from:

   ```bash
   td-chatgpt-quick-url
   ```

6. Create the connection.
7. Review the discovered tools.

There is intentionally no OAuth/login flow in this MVP. The endpoint is anonymous.

## Step 8 — test in ChatGPT

Start a new conversation, add the Tududi MVP connection from the tools menu, and begin with a read:

```text
List my Tududi projects.
```

Then try another read:

```text
Show my open Tududi tasks.
```

If reads work, test one harmless write:

```text
Create a Tududi task named "ChatGPT TryCloudflare MVP test".
```

Confirm the task appears in Tududi.

## Step 9 — stop the public endpoint

Immediately after testing:

```bash
td-chatgpt-quick-stop
```

The command stops both the Cloudflare Quick Tunnel and the local anonymous gateway and removes the saved URL.

The old URL should stop working after Cloudflare closes the tunnel.

## Commands

```bash
# Start/replace anonymous gateway + TryCloudflare tunnel
td-chatgpt-quick-restart

# Test health + MCP initialization through the public URL
td-chatgpt-quick-test

# Print the current ChatGPT MCP URL
td-chatgpt-quick-url

# Stop gateway + tunnel
td-chatgpt-quick-stop
```

## Troubleshooting

### ChatGPT cannot scan the server

First run:

```bash
td-chatgpt-quick-test
```

If it fails, restart the temporary endpoint:

```bash
td-chatgpt-quick-stop
td-chatgpt-quick-restart
td-chatgpt-quick-test
```

Then update the ChatGPT connection with the new URL from:

```bash
td-chatgpt-quick-url
```

### The URL changed

That is expected. TryCloudflare Quick Tunnels use a random hostname. Every replacement/restart can generate a different URL.

### Gateway startup fails

Check:

```bash
td-health
```

Then inspect the gateway log without printing secrets:

```bash
tail -n 100 ~/.local/state/tududi-chatgpt-quick/gateway.log
```

### Cloudflare startup fails

Inspect:

```bash
tail -n 100 ~/.local/state/tududi-chatgpt-quick/cloudflared.log
```

### Existing `td-mcp-quick-*` commands

Those commands are unchanged. They are the normal Tududi HTTP Quick Tunnel path and still require the Tududi bearer token.

For this anonymous ChatGPT MVP, use only:

```text
td-chatgpt-quick-*
```

## After the MVP

If the experiment proves that ChatGPT tool discovery and calls work, stop this anonymous version and replace it with either the OpenAI Secure MCP Tunnel approach or a real OAuth 2.1-protected public MCP endpoint.
