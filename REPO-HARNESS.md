# Repo Harness on `m1-min`

Nix/Home Manager owns the production Repo Harness entry points, the pinned
Bun/Herdr runtimes, services, tunnels, Codex integration, and the exact Repo
Harness source revision. `repo-harness-bootstrap` materializes that pinned
package payload under `~/.local/share/repo-harness/<40-char-revision>/`, while
normal CLI and hook execution goes through the Nix profile launchers with
explicit Bun paths. The legacy `~/.bun/bin` directory is not part of the managed
execution path or session PATH.

Do not run the upstream host installer over Nix-managed Claude, Codex, or editor
configuration. Do not switch the tracked runtime back to a moving Git branch for
ordinary operation.

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
| `repo-harness-protected-runtime-smoke` | Run protected-closeout authority/integration checks plus the pinned upstream journal regression |
| `repo-harness-mcp-quick-restart` | Start/replace Coding MCP and Quick Tunnel |
| `repo-harness-mcp-quick-test` | Run the end-to-end readiness check |

The protected-runtime smoke is a regression/integration check, not proof of a
live production Sprint publication. It verifies the negative protected Sprint
authority path, exercises a disposable positive protected closeout integration,
and runs the pinned upstream closeout-journal regression.

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
Therefore, `nix flake update` does not update it. The exact tested fork commit
is declared by `modules/programs/repo-harness/runtime-source.json` and consumed
by `modules/programs/repo-harness.nix`.

Changing that pin does **not** upgrade the already-active `rh-*` helpers: those
commands were built by the current generation and still embed its revision.
Build the candidate generation first and invoke its helpers directly from the
candidate per-user profile. This avoids revision-skew failures while the new
projection is being prepared.

Repo Harness 0.19.0 requires Bun 1.4.0 or newer and Herdr 0.9.0 or newer. The
module pins the corresponding upstream release assets for supported Darwin and
Linux architectures because the repository's current nixpkgs revisions are
older than those runtime floors. Unsupported platforms fail evaluation rather
than receiving a binary for the wrong OS or architecture.

For a runtime-pin upgrade, use candidate tools before activation:

```bash
cd ~/nix-config

candidate="$(nix build --no-link --print-out-paths .#darwinConfigurations.m1-min.system)"
candidate_bin="$candidate/etc/profiles/per-user/$(id -un)/bin"

"$candidate_bin/repo-harness-bootstrap"
"$candidate_bin/repo-harness-sync-host-config" --nix-config "$PWD"
"$candidate_bin/repo-harness-sync-waza" --nix-config "$PWD"
"$candidate_bin/repo-harness-sync-host-config" --check --nix-config "$PWD"
"$candidate_bin/repo-harness-sync-waza" --check --nix-config "$PWD"
"$candidate_bin/repo-harness-protected-runtime-smoke"

# Projection sync may have changed the checkout. Validate the final candidate.
nix build --no-link \
  .#checks.aarch64-darwin.repo-harness-projection-schema \
  .#checks.aarch64-darwin.repo-harness-m1-min-projection \
  .#checks.aarch64-darwin.repo-harness-mcp-scripts \
  .#darwinConfigurations.m1-min.system

sudo darwin-rebuild switch --flake .#m1-min
exec zsh
repo-harness --version
rh-check
```

The first `nix build` only produces a candidate closure; it does not activate
the host. The revision-addressed payload under `~/.local/share/repo-harness`
also remains ordinary user-owned filesystem content outside the Nix store.
Bootstrap treats a published revision as append-only and refuses to repair it
in place, but Nix itself does not make that directory immutable.

For the currently active pin, `rh-bootstrap` remains the interactive alias for
`repo-harness-bootstrap`. Use the long command in scripts and non-interactive
shells.

## Sync Repo Harness hooks into Nix

The Codex host adapter is **global, not project-local**. Do not run the upstream
host installer inside every repository and do not add project-local
`.codex/hooks.json` files.

When the runtime pin is unchanged—for example, after a Codex upgrade or while
checking projection drift—the active helper can refresh the Nix-owned projection:

```bash
cd ~/nix-config
rh-sync-host-config
rh-sync-host-config --check
sudo darwin-rebuild switch --flake .#m1-min
```

After a **Repo Harness runtime-pin change**, use the candidate helper from
[Update Repo Harness](#update-repo-harness) instead. The active helper embeds the
old runtime revision and is expected to reject a checkout with a different pin.

`rh-sync-host-config` runs the current Repo Harness installer against an isolated
temporary HOME, validates the generated Codex adapter, and copies the reviewed hook
projection into the single compatibility artifact
`modules/programs/repo-harness/codex-projection.json`. It rewrites managed hook
dispatch to the Nix-owned Repo Harness launchers, builds the Codex candidate from
the current `m1-min` flake, keeps that candidate rooted with a temporary Nix
out-link for the duration of the probe, and asks its app-server for the
authoritative `hooks/list` keys and `currentHash` values. Promotion fails if
that Codex candidate cannot be resolved; ambient-PATH fallback is available only
through an explicit diagnostic flag. Hook text, all 12 trust hashes, Repo Harness
revision, source, and Codex executable are updated atomically in one JSON file.
The helper never writes directly to the real `~/.codex` directory.

Run the active helper after a Codex upgrade or for projection maintenance when
the Repo Harness runtime pin is unchanged. After a Repo Harness runtime-pin
upgrade, run the candidate helper described above. In either case, the sync
derives trust from the checkout's Nix Codex candidate before activation.
`rh-sync-host-config --check` fails when the generated projection is stale.

`modules/programs/codex.nix` remains the source of truth for the real
`~/.codex/config.toml` and `~/.codex/hooks.json` Home Manager links. If a future
Repo Harness version generates new TOML requirements, the sync helper fails closed
and asks for an explicit Nix change instead of silently widening the host config.
The generated `[hooks.state]` entries also mean Codex does not need to persist hook
approval into the immutable Nix-store `config.toml`.

## Sync Repo Harness Waza into Nix

Waza is a **host capability**, not project-local setup. New repositories should not
run `bunx skills add tw93/Waza` or otherwise mutate `~/.codex/skills`. With the
runtime pin unchanged, refresh or validate the Nix-owned Waza projection with:

```bash
cd ~/nix-config
rh-sync-waza
rh-sync-waza --check
sudo darwin-rebuild switch --flake .#m1-min
```

After a Repo Harness runtime-pin change, use the candidate `repo-harness-sync-waza`
from [Update Repo Harness](#update-repo-harness) before activation.

`rh-sync-waza` asks the pinned Repo Harness runtime for its Codex Waza
contract (source repository, managed skills, shared rules, and primary host) from
a blank temporary Git repository. The default update mode resolves upstream Waza
`HEAD`, prefetches that archive through Nix, validates every declared path, and
atomically writes `modules/programs/repo-harness/waza-source.json` together with
the Repo Harness revision that declared the contract. `rh-sync-waza --check` is
deterministic and validates the committed pin against the pinned runtime without
consulting upstream HEAD. Use `rh-sync-waza --update-check` for online update
discovery. The real `~/.agents` and `~/.codex` trees are never modified by the
sync helper.

`modules/programs/codex.nix` consumes the generated revision, fixed-output hash,
managed-skill list, and shared-rule list. Home Manager recursively projects the
managed skill files under a normal writable `~/.codex/skills` directory instead
of making the parent directory a Nix-store symlink. This is required by Codex
0.154+, which materializes its own system-skill metadata in that parent directory.
A guarded activation migration removes the old parent symlink only when it points
to a Home-Manager-owned `*-home-manager-files/.codex/skills` store path.

After a runtime-pin change, use the candidate-helper sequence in
[Update Repo Harness](#update-repo-harness). Do not substitute the currently
active `rh-sync-*` commands before activation: their compiled runtime revision
may intentionally differ from the checkout and the skew guard will reject that
combination.

After activation, verify the active generation normally:

```bash
rh-sync-host-config --check
rh-sync-waza --check
repo-harness setup check --target codex --json
```

After that switch, every new Repo Harness project reuses the same global Waza
`think`, `hunt`, `check`, and `health` skills. Project adoption remains repo-local;
Waza installation does not repeat per repository.

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
