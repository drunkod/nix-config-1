# Repo Harness documentation

This is the workflow selector for the Nix-managed `m1-min` setup. Read the
shared [`safety rules`](safety.md), then choose one current procedure.

## Choose a workflow

| Goal | Quick tutorial | Canonical authority |
|---|---|---|
| Plan from workflow artifacts | [Planner](quick/planner.md) | [Workflow concepts](quick/workflow-concepts.md) |
| Edit in an isolated managed worktree | [Coding MCP](quick/coding.md) | [Guides 1–4](#canonical-guides) |
| Consult logged-in ChatGPT Web | [Browser Engine](quick/browser-engine.md) | [Browser reference](reference/browser-engine-github-create-review.md) |
| Create/review with the GitHub app | [Browser Create/Review](quick/browser-engine.md#github-create-and-review) | [Browser reference](reference/browser-engine-github-create-review.md) |
| Publish MCP temporarily | [Quick Tunnel](quick/tunnels.md#quick-tunnel-default) | [Guide 3](guides/03-start-coding-mcp-quick-tunnel.md) |
| Use a stable Cloudflare hostname | [Named Tunnel](quick/tunnels.md#named-tunnel-optional) | [Tunnel internals](reference/quick-tunnel-internals.md) |
| Solve a daily development task | [Developer recipes](../developer-recipes/README.md) | Recipe-specific |
| Discover every installed 0.15 CLI surface | [CLI toolbox](quick/cli-toolbox.md) | Installed `--help` and bundled docs |

Quick tutorials are abbreviated. The numbered guides own current setup and
operational sequencing. References explain internals and uncommon variants.
History records observed runs and is not current instruction.

## Fast adoption

```bash
cd /absolute/path/to/repository
repo-harness init --mode minimal --no-codegraph --no-verify --dry-run
repo-harness init --mode minimal --no-codegraph --no-verify
repo-harness status --json
```

Review and commit adoption before granting writes. Minimal mode installs the core MCP, task, and handoff scaffolding while
intentionally omitting the complete standard policy, context, and architecture
surfaces. `--no-verify` makes that deliberate MCP-only boundary explicit. Use
`--mode standard` for the complete workflow contract, and preview exact
operations because generated artifact sets can change between releases.

Continue with [guide 1](guides/01-onboard-repository.md) when the repository has
not been reviewed for adoption, or the [Coding quick tutorial](quick/coding.md)
when adoption is already committed.

## Update the CLI

Repo Harness is installed from the moving upstream `mvp` Git branch through
Bun; it is not a declared flake input. `nix flake update` does not update it.
Refresh and verify it explicitly:

```bash
rh-bootstrap
repo-harness --version
rh-check
```

Use `repo-harness-bootstrap` instead of the `rh-bootstrap` alias in scripts and
non-interactive shells. See the top-level [Repo Harness host guide](../../REPO-HARNESS.md#update-repo-harness)
for the distinction between CLI, Nix configuration, and flake-input updates.

## Canonical guides

1. [Onboard a repository](guides/01-onboard-repository.md)
2. [Initialize CodeGraph](guides/02-initialize-codegraph.md)
3. [Start Coding MCP and Quick Tunnel](guides/03-start-coding-mcp-quick-tunnel.md)
4. [Daily Coding workflow](guides/04-daily-coding-workflow.md)
5. [Operations, security, and troubleshooting](guides/05-operations-security-troubleshooting.md)

## Quick tutorials

- [Planner](quick/planner.md)
- [Coding MCP](quick/coding.md)
- [Browser Engine and GitHub Create/Review](quick/browser-engine.md)
- [Quick and named tunnels](quick/tunnels.md)
- [Workflow concepts for installed `0.15.0`](quick/workflow-concepts.md)
- [Repo Harness 0.15 CLI toolbox](quick/cli-toolbox.md)

## Specialist references

- [`m1-min` Coding MCP implementation](reference/m1-min-coding-mcp.md)
- [Quick Tunnel internals](reference/quick-tunnel-internals.md)
- [Browser Engine and GitHub Create/Review](reference/browser-engine-github-create-review.md)

## Historical evidence

- [Browser Create smoke test, 2026-08-03](history/browser-create-smoke-test-2026-08-03.md)

## Version boundary

The public website may use a different command surface from installed Repo Harness
`0.15.0`. The complete mapping belongs in
[workflow concepts](quick/workflow-concepts.md). Confirm availability with:

```bash
repo-harness --help
repo-harness run --help
```

Back to the [documentation index](../README.md).
