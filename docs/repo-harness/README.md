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
| Inspect legacy 0.15 command mappings | [Historical CLI toolbox](quick/cli-toolbox.md) | Installed pinned CLI `--help` is authoritative |

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

Repo Harness is installed from an exact tested fork revision declared in
`modules/programs/repo-harness/runtime-source.json`; it is not a flake input.
`nix flake update` does not update it.

If the runtime pin itself changes, do not start the upgrade with the currently
active `rh-bootstrap` or `rh-sync-*` commands. Those helpers belong to the
active generation and embed its revision. Build the new Darwin candidate, run
the candidate's per-user Repo Harness helpers, validate the resulting checkout,
and only then activate it. The complete command sequence is in the top-level
[Repo Harness host guide](../../REPO-HARNESS.md#update-repo-harness).

For repair or verification of the **currently active pin**, the normal aliases
remain valid:

```bash
rh-bootstrap
repo-harness --version
rh-sync-host-config --check
rh-sync-waza --check
rh-smoke
rh-check
```

A successful `nix build` is candidate validation, not host activation. The
revision-addressed runtime directory is outside the Nix store and is protected
by bootstrap's no-in-place-mutation policy rather than Nix-store immutability.

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
- [Historical 0.15 workflow concepts](quick/workflow-concepts.md)
- [Historical 0.15 CLI toolbox](quick/cli-toolbox.md)

## Specialist references

- [`m1-min` Coding MCP implementation](reference/m1-min-coding-mcp.md)
- [Quick Tunnel internals](reference/quick-tunnel-internals.md)
- [Browser Engine and GitHub Create/Review](reference/browser-engine-github-create-review.md)

## Historical evidence

- [Browser Create smoke test, 2026-08-03](history/browser-create-smoke-test-2026-08-03.md)

## Version boundary

The public website and historical 0.15 guides may use a different command
surface from the pinned Repo Harness 0.19.0 runtime. Treat the historical
workflow/CLI pages as migration context only. Confirm the current command surface
with:

```bash
repo-harness --help
repo-harness run --help
```

Back to the [documentation index](../README.md).
