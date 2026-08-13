# Repo-harness on `m1-min`

This configuration uses a two-stage repo-harness installation:

1. Home Manager installs Bun, helper commands, aliases, and a safe `repo-harness` launcher.
2. `rh-bootstrap` installs or refreshes the actual repo-harness CLI under `~/.bun/bin`.

The second stage is intentional. The upstream CLI is currently managed as mutable Bun state rather than as a pinned Nix package.

## Start here

Use the three guides in order:

1. [`docs/repo-harness-01-onboard-repository.md`](docs/repo-harness-01-onboard-repository.md) — clone/create a repository, define `.ignore`, preview and commit adoption, grant access, and refresh OAuth.
2. [`docs/repo-harness-02-daily-workflow.md`](docs/repo-harness-02-daily-workflow.md) — run the read-only canary, select the exact `repo_id` and base SHA, open a managed worktree, edit, validate, review, and clean up.
3. [`docs/repo-harness-03-operations-security-troubleshooting.md`](docs/repo-harness-03-operations-security-troubleshooting.md) — operate the Quick Tunnel/OAuth service, understand allowed and prohibited actions, and recover from common failures.

The older Browser Engine, Browser Create, full `m1-min`, and Quick Tunnel documents are specialist references. They are not the default onboarding path.

The default workflow is:

```text
existing Git repository
  -> reviewed Repo Harness adoption
    -> explicit per-repository access
      -> authenticated Coding MCP
        -> isolated managed worktree
          -> bounded edit, targeted check, and human-reviewed diff
```

Do not confuse this with the separate Browser Engine + GitHub app Create/Review workflow.

## Initial setup

Rebuild the host configuration:

```bash
cd ~/nix-config
sudo darwin-rebuild switch --flake .#m1-min
```

Start a fresh shell so Home Manager's PATH and aliases are active:

```bash
exec zsh
```

Before the first bootstrap, this command should print a direct setup message instead of falling through to the shell's command-not-found handler:

```bash
repo-harness --version
```

Install the actual CLI:

```bash
rh-bootstrap
```

Verify it:

```bash
repo-harness --version
repo-harness chatgpt browser-create --help
rh-check
```

`rh-check` audits the broader host setup, including optional global adapters, CodeGraph, external skills, agent definitions, trust state, and security findings. A `blocked` result does not by itself mean that the CLI bootstrap failed. Confirm the CLI-specific checks and address only the optional capabilities that this host should enable.

## Available helper commands

| Command | Purpose |
|---|---|
| `rh-bootstrap` | Install or refresh repo-harness in `~/.bun/bin` |
| `rh-generate-host-config` | Run upstream host installation inside an isolated temporary home for inspection |
| `rh-init` | Preview initialization or refresh of the current repository |
| `rh-check` | Run `repo-harness setup check --json` |

The long command names remain available:

```text
repo-harness-bootstrap
repo-harness-generate-host-config
repo-harness-init-current
repo-harness-check
```

## Initialize or refresh a repository

Enter the target repository and preview the changes:

```bash
cd /path/to/repository
rh-init
```

Apply the initialization only after reviewing the preview:

```bash
repo-harness init
```

Run the canonical workflow check:

```bash
repo-harness run check-task-workflow --strict
```

Do not use the older downstream form:

```text
bash scripts/check-task-workflow.sh --strict
```

Repo-harness keeps the implementation of that helper in the installed package runtime.

## Inspect upstream host projections safely

The normal `m1-min` rebuild does not let the upstream installer mutate Home Manager-owned Claude or Codex files.

To inspect what upstream repo-harness would generate, run:

```bash
rh-generate-host-config
```

The helper creates a temporary home, installs repo-harness there, runs `repo-harness install`, and prints the generated paths. Nothing is written to the real home directory.

Port only deliberately selected settings, hooks, agents, or skills into the Nix configuration.

## ChatGPT Browser Plan, Create, Review

For the full setup walkthrough, Chrome binding, Browser Engine smoke test, GitHub-app Create stage, and independent Review stage, see [`docs/repo-harness-chatgpt-browser-setup.md`](docs/repo-harness-chatgpt-browser-setup.md).

The minimal workflow separates durable repo-harness artifacts from GitHub actions:

```text
ChatGPT Browser planning
        ↓
approved plan and task contract
        ↓
ChatGPT GitHub app creates a branch, files, commit, and draft PR
        ↓
new ChatGPT Browser review session
        ↓
human approval or correction
```

Recommended durable paths:

```text
plans/plan-<task>.md
tasks/contracts/<task>.contract.md
.ai/harness/handoff/chatgpt/create-<timestamp>-<task>.md
tasks/reviews/<task>.review.md
```

The Browser Engine is the repo-harness planning and review transport. GitHub-app writes are a separate ChatGPT capability available in the connected environment; they are not an upstream repo-harness file-writing feature.

Keep these boundaries:

- planning must not modify implementation files;
- creation must remain inside the approved contract paths;
- review must use the final PR patch and current CI evidence;
- replies, thread resolution, reruns, pushes, PR creation, and merge are explicit write actions;
- merge remains a human decision.

## Troubleshooting

### `repo-harness CLI is not installed yet`

Run:

```bash
rh-bootstrap
```

### `__pr_base:1: bad substitution`

`__pr_base` belongs to the shell command-correction integration and is invoked when a command cannot be found. The configured `repo-harness` launcher prevents the expected first-run state from reaching that handler.

After applying this change, rebuild and start a fresh shell:

```bash
sudo darwin-rebuild switch --flake .#m1-min
exec zsh
```

### The CLI was installed but the shell still uses an old command path

Run:

```bash
rehash
```

or restart the shell:

```bash
exec zsh
```

### Bun installation fails

Confirm network access and Bun operation:

```bash
bun --version
bun add -g \
  'git+https://github.com/drunkod/repo-harness.git#agent/chatgpt-github-create-mvp'
```

Then retry:

```bash
rh-bootstrap
```

## Upgrade behavior

`darwin-rebuild` updates the Nix-managed launcher and helper commands. It does not silently update the mutable repo-harness CLI.

Refresh the CLI explicitly when desired:

```bash
rh-bootstrap
repo-harness --version
```
