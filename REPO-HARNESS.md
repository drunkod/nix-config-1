# Repo Harness on `m1-min`

This repository installs Repo Harness in two stages:

1. Nix/Home Manager owns Bun, helper commands, services, tunnels, and agent
   integration.
2. `repo-harness-bootstrap` installs or refreshes the mutable Repo Harness CLI
   under `~/.bun/bin`.

Do not run the upstream host installer over Nix-managed Claude, Codex, or editor
configuration.

## Install or refresh

```bash
cd ~/nix-config
sudo darwin-rebuild switch --flake .#m1-min
exec zsh
repo-harness-bootstrap
repo-harness --version
```

The short interactive alias is `rh-bootstrap`.

## Common helpers

| Command | Purpose |
|---|---|
| `repo-harness-bootstrap` | Install or refresh the CLI |
| `repo-harness-generate-host-config` | Inspect upstream host projections in an isolated temporary home |
| `repo-harness-init-current` | Preview initialization of the current repository |
| `repo-harness-check` | Run the host/setup audit |
| `repo-harness-mcp-quick-restart` | Start/replace Coding MCP and Quick Tunnel |
| `repo-harness-mcp-quick-test` | Run the end-to-end readiness check |

Interactive Zsh also exposes shorter `rh-*` aliases. Use canonical long names in
scripts and non-interactive shells.

## Documentation map

- [Repo Harness workflow selector](docs/repo-harness/README.md)
- [Shared safety rules](docs/repo-harness/safety.md)
- [Canonical numbered guides](docs/repo-harness/README.md#canonical-guides)
- [Quick tutorials](docs/repo-harness/README.md#quick-tutorials)
- [Specialist references](docs/repo-harness/README.md#specialist-references)
- [Historical evidence](docs/repo-harness/README.md#historical-evidence)
- [Everyday developer recipes](docs/developer-recipes/README.md)

## Upgrade behavior

A Nix rebuild updates the launcher, services, and helper commands. It does not
silently update the mutable Repo Harness CLI. Refresh it explicitly:

```bash
repo-harness-bootstrap
repo-harness --version
```
