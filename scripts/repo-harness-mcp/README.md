# Repo Harness MCP coding scripts

These scripts are the small, reviewable prototype used to translate the
upstream manual coding-profile tutorial into the `m1-min` Nix configuration.
They intentionally separate local state, long-running processes, Cloudflare
account changes, DNS changes, and ChatGPT UI work.

The durable `m1-min` processes are managed by the Home Manager modules:

- `services.repo-harness-mcp`;
- `services.cloudflared-mcp-tunnel`.

The foreground start scripts remain useful for diagnosis. Interactive and
external operations remain explicit bootstrap steps because they cannot be
made safely declarative without introducing credentials or account authority
into the Nix build.

## Order

1. `00-check-prerequisites.sh`
2. `10-check-dependencies.sh`
3. `20-initialize-repo-harness.sh --repo /path --dry-run`
4. `20-initialize-repo-harness.sh --repo /path --apply`
5. `60-cloudflare-login.sh`
6. `70-cloudflare-create-tunnel.sh --name repo-harness-coding`
7. `80-cloudflare-configure-dns.sh --tunnel UUID --hostname HOST`
8. `90-cloudflare-write-config.sh ... --dry-run`
9. `30-configure-mcp-coding-profile.sh --repo /path --endpoint https://HOST/mcp --dry-run`
10. Apply both configuration commands, then use the Nix-managed services.
11. `120-run-mcp-doctor.sh --repo /path`
12. `130-run-coding-profile-smoke-test.sh --repo /path`

`140-cleanup-or-rollback.sh` is dry-run by default. It never deletes a
Cloudflare tunnel, DNS record, login certificate, or credentials file.
