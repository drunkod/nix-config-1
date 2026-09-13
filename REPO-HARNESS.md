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
repo-harness-sync-host-config
sudo darwin-rebuild switch --flake .#m1-min
```

The short interactive alias is `rh-bootstrap`.

## Common helpers

| Command | Purpose |
|---|---|
| `repo-harness-bootstrap` | Install or refresh the CLI |
| `repo-harness-generate-host-config` | Inspect upstream host projections in an isolated temporary home |
| `repo-harness-sync-host-config` | Sync the current Repo Harness Codex hook projection into Nix |
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
rh-sync-host-config
sudo darwin-rebuild switch --flake .#m1-min
rh-check
```

`rh-bootstrap` is the interactive Zsh alias for
`repo-harness-bootstrap`. Use the long command in scripts and non-interactive
shells.

## Sync Repo Harness hooks into Nix

The Codex host adapter is **global, not project-local**. Do not run the upstream
host installer inside every repository and do not add project-local
`.codex/hooks.json` files.

After installing or upgrading Repo Harness, refresh the Nix-owned projection once:

```bash
cd ~/nix-config
rh-sync-host-config
rh-sync-host-config --check
sudo darwin-rebuild switch --flake .#m1-min
```

`rh-sync-host-config` runs the current Repo Harness installer against an isolated
temporary HOME, validates the generated Codex adapter, and copies the reviewed hook
projection to `modules/programs/repo-harness/codex-hooks.json`. It then builds/resolves
the Codex candidate from the current `m1-min` flake, keeps that candidate rooted with
a temporary Nix out-link for the duration of the probe, and asks its app-server for the
authoritative `hooks/list` keys and `currentHash` values. If no Nix candidate can be
resolved it falls back to the active `codex` on `PATH`. The 12 Repo Harness trust
hashes are written to `modules/programs/repo-harness/codex-hook-trust.json`; the
helper never writes directly to the real `~/.codex` directory.

Run this sync after either a Repo Harness upgrade **or a Codex upgrade**. Because the
Nix candidate is preferred, hook-hash drift is detected before the new generation is
activated. `rh-sync-host-config --check` fails when either generated projection is
stale.

`modules/programs/codex.nix` remains the source of truth for the real
`~/.codex/config.toml` and `~/.codex/hooks.json` Home Manager links. If a future
Repo Harness version generates new TOML requirements, the sync helper fails closed
and asks for an explicit Nix change instead of silently widening the host config.
The generated `[hooks.state]` entries also mean Codex does not need to persist hook
approval into the immutable Nix-store `config.toml`.

Codex project trust is exact-path rather than inherited from a parent directory.
The Nix-managed `codex` launcher therefore resolves the current Git root and injects
an exact transient `trust_level = "trusted"` override only when that root is inside
`~/Documents/work`, which is the workspace already designated as trusted on this
machine. Repositories outside that boundary still use normal Codex trust handling.
Known repositories may also remain as explicit project entries for clients that
bypass the shell launcher.

After activation, restart Codex and verify without accepting or persisting any new
Repo Harness hook trust manually:

```bash
repo-harness setup check --target codex --json
```

A new project under `~/Documents/work` needs only repo-local adoption:

```bash
cd ~/Documents/work/new-project
repo-harness init
repo-harness run check-task-workflow --strict
codex
```

The global hook adapter discovers the current Git root at runtime and applies the
Repo Harness workflow only to adopted repositories, so no host-hook copy or trust
write is needed per project.

A Nix rebuild is needed after changing the Nix-managed runtime pins, launcher,
services, helpers, source URL, or generated host projection. Updating normal flake
inputs remains a separate action:

```bash
nix flake update             # update every declared input
nix flake update input-name  # update one declared input
```
