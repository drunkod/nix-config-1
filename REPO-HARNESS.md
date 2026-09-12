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

## Update Repo Harness

Repo Harness is not a flake input and is not recorded in `flake.lock`.
Therefore, `nix flake update` does not update the CLI. The source configured in
`modules/programs/repo-harness.nix` is the fork's adopted `main` branch.

Repo Harness 0.19.0 requires Bun 1.4.0 or newer and Herdr 0.9.0 or newer. The
module currently pins the validated macOS arm64 Bun 1.4.0 and Herdr 0.9.0
release assets directly because the repository's current nixpkgs revisions are
older than those runtime floors.

Refresh the CLI explicitly, then verify the installed version:

```bash
rh-bootstrap
repo-harness --version
rh-check
```

`rh-bootstrap` is the interactive Zsh alias for
`repo-harness-bootstrap`. Use the long command in scripts and non-interactive
shells.

A Nix rebuild is needed after changing the Nix-managed runtime pins, launcher,
services, helpers, or source URL. Updating normal flake inputs remains a separate
action:

```bash
nix flake update             # update every declared input
nix flake update input-name  # update one declared input
```
