# Repo Harness MCP scripts: support status

This directory is a historical coding + named-Cloudflare-tunnel prototype. It is
**not** the current default `m1-min` setup sequence.

Start with the [Repo Harness documentation](../../docs/repo-harness/README.md).

## Current default commands

Nix-generated helpers own the normal Coding + Quick Tunnel workflow:

```bash
repo-harness-mcp-quick-restart
repo-harness-mcp-quick-test
repo-harness-mcp-quick-url
repo-harness-mcp-chatgpt-auth
repo-harness-mcp-bootstrap
repo-harness-mcp-restart
repo-harness-mcp-health
repo-harness-mcp-doctor
```

Do not replace these with the old numbered sequence.

## Script classification

| Script | Status | Use |
|---|---|---|
| `lib.sh` | current shared library | Common validation helpers |
| `00-check-prerequisites.sh` | diagnostic | Broad historical preflight; requires more than adoption needs |
| `10-check-dependencies.sh` | diagnostic/redundant | Historical dependency check |
| `20-initialize-repo-harness.sh` | superseded | Use explicit `repo-harness init --mode ... --no-codegraph` after reviewing `.ignore` |
| `30-configure-mcp-coding-profile.sh` | superseded | Use `repo-harness-mcp-bootstrap` |
| `40-start-local-mcp-server.sh` | diagnostic | Foreground Coding server investigation only |
| `50-check-local-mcp-health.sh` | diagnostic | Prefer `repo-harness-mcp-health` |
| `60-cloudflare-login.sh` | current optional | Named Tunnel Cloudflare login |
| `70-cloudflare-create-tunnel.sh` | current optional | Create named Cloudflare tunnel |
| `80-cloudflare-configure-dns.sh` | current optional | Add named-tunnel DNS route |
| `90-cloudflare-write-config.sh` | superseded | Use `cloudflared-mcp-tunnel-init`; Nix owns runtime config generation |
| `100-cloudflare-run-tunnel.sh` | diagnostic | Foreground named-tunnel troubleshooting only |
| `110-configure-chatgpt-endpoint.sh` | superseded | It only wraps old script `30`; it cannot configure ChatGPT UI |
| `120-run-mcp-doctor.sh` | diagnostic | Prefer `repo-harness-mcp-doctor` |
| `130-run-coding-profile-smoke-test.sh` | diagnostic/obsolete gate | Prefer `repo-harness-mcp-quick-test` plus visible ChatGPT canaries |
| `140-cleanup-or-rollback.sh` | limited cleanup | Stops services, can downgrade one repo, can remove old generated YAML; not a full rollback |

## Current sequences

### Repository adoption

```bash
cd /absolute/repository
repo-harness init --mode minimal --no-codegraph --dry-run
repo-harness init --mode minimal --no-codegraph --no-verify
```

Use `standard` for the full workflow contract. Applying `init` automatically
registers the repository read-only, so review `.ignore` first.

### Coding + Quick Tunnel

```bash
codegraph init "$PWD"
repo-harness mcp access set --repo "$PWD" --mode read_write --json

# First setup only: create enabled local config before the health-gated helper.
repo-harness-mcp-bootstrap --repo "$PWD" --endpoint https://mcp.invalid/mcp
repo-harness-mcp-restart

repo-harness-mcp-quick-restart
repo-harness-mcp-quick-test
repo-harness-mcp-chatgpt-auth
```

Do not configure ChatGPT with the `mcp.invalid` bootstrap placeholder.

Each managed worktree needs `codegraph init .` before its first patch.

### Optional named tunnel

```bash
./60-cloudflare-login.sh
./70-cloudflare-create-tunnel.sh --name repo-harness-coding
./80-cloudflare-configure-dns.sh --tunnel <uuid> --hostname mcp.example.com

cloudflared-mcp-tunnel-init \
  --tunnel-id <uuid> \
  --hostname mcp.example.com \
  --credentials-file "$HOME/.cloudflared/<uuid>.json"
```

Enable the Nix named-tunnel module and rebuild **before** running
`cloudflared-mcp-tunnel-init`, because that helper is installed only while the
module is enabled. Then bootstrap the stable endpoint and restart the Nix
services. Do not use scripts `90`/`100` as the managed service path.

### Planner

There are no Planner scripts here. The current `m1-min` service is Coding-only.
Use a separate manually served Planner profile/port; see
[Planner quick tutorial](../../docs/repo-harness/quick/planner.md).

### Browser Engine / GitHub Create

There are no Browser Engine scripts here. Use the installed
`repo-harness chatgpt browser-*` commands; see
[Browser Engine quick tutorial](../../docs/repo-harness/quick/browser-engine.md).

## Cleanup limitations

`140-cleanup-or-rollback.sh` is dry-run by default and never deletes external
Cloudflare tunnels, DNS, certificates, or credentials. It also does not:

- stop/remove helper-owned Quick Tunnel state;
- undo repository adoption;
- perform a Nix generation rollback;
- remove OAuth/MCP config;
- remove named-tunnel parameter state;
- clean Repo Harness managed worktrees.

Use it only for the actions shown by its dry run. For actual Nix rollback, use
the platform's Nix generation rollback workflow.

## Security

- Keep MCP bound to loopback.
- Never commit OAuth, Cloudflare, browser, or Repo Harness mutable state.
- Never grant a broad parent directory.
- Do not use shell commands to bypass Repo Harness path denials.
- Do not repeat a successful mutation because only CodeGraph refresh failed.
