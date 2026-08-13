# Repo Harness Planner MCP: short tutorial

Use Planner when ChatGPT should inspect workflow state and write planning/handoff
artifacts, but should not receive direct Coding MCP application-file/shell tools.
Planner can write approved workflow artifacts such as PRDs, sprints, plans,
goals, handoff notes, and check evidence.

## 1. Adopt the repository

```bash
cd /absolute/path/to/repository
repo-harness init --mode standard --no-codegraph --dry-run
repo-harness init --mode standard --no-codegraph
```

Review and commit adoption. Use minimal mode only when you intentionally accept
that the full strict workflow check will fail.

## 2. Understand the current `m1-min` limitation

The installed CLI supports Planner, but the current `m1-min` deployment owns one
enabled user-scoped Coding configuration in `~/.repo-harness`. That user config
takes precedence over repository-scoped Planner configuration.

Therefore **do not attempt to run Planner concurrently** by merely choosing a
different port or `--scope repo`; it can still resolve Coding OAuth/config state.
The Coding Quick Tunnel also publishes only port `8765`.

Supported choices today:

1. use the existing Coding connector's planning/workflow tools without opening a
   coding workspace;
2. use Browser Engine consultation for planning;
3. implement a separate Nix-managed Planner service with isolated Repo Harness
   state and endpoint as a future change;
4. stop Coding and deliberately replace the single user-scoped profile with
   Planner, accepting that Coding must later be restored and reauthorized.

This tutorial recommends option 1 or 2. It does not provide an unsafe
concurrent-server command.

## 3. Verify the selected planning surface

For Coding connector planning, run the normal five-layer Coding doctor and then
call only planning tools. For Browser Engine, follow
[`repo-harness-browser-engine-quick.md`](repo-harness-browser-engine-quick.md).

## 4. First canary

```text
Use Repo Harness Planner and call harness_status only.
Do not modify implementation files or run shell commands.
```

Then use workflow planning tools only. Planner is not the direct source-editing
path; use Coding MCP for managed-worktree edits.

## Repository access versus Planner writes

Adopted repositories are registered read-only by `init`. That access mode limits
general repository reads/mutations, but Planner can still write its approved
workflow-artifact surface. Planner is not application-source Coding, but it is
not completely read-only.

## Stop

Stop the foreground server with `Ctrl+C`. OAuth/config state remains under
`~/.repo-harness` and must never be committed.
