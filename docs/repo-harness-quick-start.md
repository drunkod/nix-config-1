# Repo Harness quick start: choose one mode

This is the short entry point for `m1-min`. Choose one workflow; do not combine
all features during initial setup.

## Which mode do I need?

| Goal | Use | Authority |
|---|---|---|
| Ask ChatGPT to plan from workflow files | [Planner options](repo-harness-planner-quick.md) | Workflow-artifact writes, no direct Coding workspace |
| Let ChatGPT edit in isolated local worktrees | [Coding MCP](repo-harness-coding-quick.md) | Explicit repo `read_write` + local shell |
| Use logged-in ChatGPT Web for consultation | [Browser Engine](repo-harness-browser-engine-quick.md) | Selected workflow files only |
| Let ChatGPT GitHub app create branch/commit/draft PR | [Browser Create/Review](repo-harness-browser-engine-quick.md#github-create-and-review) | Explicit GitHub writes |
| Publish MCP temporarily | [Quick Tunnel](repo-harness-tunnels-quick.md#quick-tunnel-default) | Ephemeral HTTPS URL |
| Publish MCP on stable custom hostname | [Named Tunnel](repo-harness-tunnels-quick.md#named-tunnel-optional) | Cloudflare account, DNS, credentials |
| Use PRD → Sprint → Goal workflow | [Workflow mapping](repo-harness-workflow-quick.md) | Repo-local durable artifacts |

## Common prerequisite

```bash
repo-harness --version
```

On this Nix configuration, install/refresh the fork with:

```bash
repo-harness-bootstrap
```

Do not use the public website's curl/npm installer and do not run upstream host
installers over Nix-managed agent configuration.

## Adopt a repository once

Detailed safety instructions are in
[`repo-harness-01-onboard-repository.md`](repo-harness-01-onboard-repository.md).
The compact form is:

```bash
cd /absolute/path/to/repository

# Review .ignore before init: init registers the repo read_only.
repo-harness init --mode minimal --no-codegraph --dry-run
repo-harness init --mode minimal --no-codegraph --no-verify

repo-harness status --json
```

Review and commit the generated files before granting writes. Minimal mode is
enough for Coding MCP but does not pass the full strict workflow checker.

For complete Repo Harness workflow adoption, use `--mode standard` instead.

## Optional CodeGraph

```bash
codegraph init /absolute/path/to/repository
codegraph status /absolute/path/to/repository
```

Nix already installs and wires CodeGraph. Never run `codegraph install` or
`codegraph upgrade`. Each managed worktree needs its own `codegraph init .`.

## Important version boundary

The public website currently documents newer commands such as:

```text
repo-harness adopt
repo-harness prd
repo-harness sprint
repo-harness goal
repo-harness check
repo-harness ship
```

Your installed fork at version `0.12.0` does not expose those top-level commands.
Use [`repo-harness-workflow-quick.md`](repo-harness-workflow-quick.md) for the
verified equivalents. Always confirm commands with `repo-harness --help`.

## Deep references

The numbered guides remain detailed references:

1. repository adoption;
2. CodeGraph;
3. Coding MCP + Quick Tunnel;
4. daily managed-worktree work;
5. security and troubleshooting.
