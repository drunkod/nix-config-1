# CodeGraph workflow

This guide describes how to use CodeGraph safely with this Nix configuration.
It is based on local tests with CodeGraph 1.5.0 on `aarch64-darwin`, not only on
upstream documentation.

## What this configuration manages

The Home Manager module in `modules/programs/codegraph.nix` does two things:

1. installs `pkgs.llm-agents.codegraph` on `PATH`;
2. registers the following MCP server through the shared MCP registry:

```text
codegraph serve --mcp
```

The shared registry propagates CodeGraph to Claude Code, Codex, and Zed. Do not
run CodeGraph's agent installer: Nix owns those generated configurations.

CodeGraph and Graphify are separate tools and can coexist:

| Tool | Per-project state | MCP server |
| --- | --- | --- |
| CodeGraph | `.codegraph/` | `codegraph` |
| Graphify | `graphify-out/` | `graphify` |

## First-time setup for a project

From anywhere, pass the project path explicitly:

```bash
codegraph init /absolute/path/to/project
codegraph status /absolute/path/to/project
```

`codegraph init` creates and builds `/absolute/path/to/project/.codegraph/`.
Initialization is per project; installing the CLI does not index every project.

Ensure the project ignores the generated database:

```gitignore
.codegraph/
```

This repository already contains that ignore rule.

## Normal daily workflow

After initialization, open the project in Claude Code, Codex, or Zed normally.
The declarative MCP server starts for the agent and uses the indexed project.
It watches source changes and performs incremental synchronization while it is
running.

Useful health check:

```bash
codegraph status /absolute/path/to/project
```

Use an explicit synchronization before important structural or impact queries
after a large source change:

```bash
codegraph sync /absolute/path/to/project
```

This is particularly useful after:

- switching branches;
- rebasing or merging;
- pulling a large change;
- generating or deleting many source files;
- modifying files while no CodeGraph MCP server was running.

Local testing found that `codegraph status` could report zero pending changes
immediately after an edit even though the following `codegraph sync` detected
and indexed the modified file. Treat `sync` as the reliable preflight; do not
use `status.pendingChanges` alone as a freshness guarantee.

## Asking agents to use the correct project

For a single-root workspace, CodeGraph can discover the nearest `.codegraph/`
index from the project context. A path inside an indexed project also resolves
upward to that project's index.

For multi-root workspaces, monorepos with separate indexes, or cross-project
questions, provide the exact project root. In MCP calls this is the
`projectPath` argument. In the CLI, use `--path`:

```bash
codegraph explore \
  "How does authentication reach the database?" \
  --path /absolute/path/to/api

codegraph query UserService \
  --path /absolute/path/to/api \
  --json
```

Prefer absolute paths in documentation, scripts, and durable configuration.
Relative paths are acceptable for interactive commands when their resolution is
unambiguous.

## Multiple independent projects

Initialize every repository separately:

```bash
codegraph init ~/work/api
codegraph init ~/work/frontend
codegraph init ~/nix-config
```

The resulting layout must be:

```text
~/work/api/.codegraph/
~/work/frontend/.codegraph/
~/nix-config/.codegraph/
```

Local testing initialized two repositories simultaneously. Each received a
distinct SQLite database in WAL mode, and symbol queries against one project did
not return symbols that existed only in the other project.

Multiple MCP server processes are supported. A local concurrency probe kept
three processes alive simultaneously with no lock errors:

- one process for project A;
- one process for project B;
- a second process for project A.

This means Claude Code, Codex, and Zed may use CodeGraph concurrently. Each
client should still identify the intended project root.

## Git branches in one checkout

A normal branch switch keeps the same working directory and therefore the same
`.codegraph/` database. Synchronize after the switch:

```bash
git switch feature/example
codegraph sync /absolute/path/to/project
codegraph status /absolute/path/to/project
```

Use a full rebuild if synchronization fails or the index reports that a reindex
is recommended:

```bash
codegraph index --force /absolute/path/to/project
```

Do not assume that an index built on the previous branch is immediately correct
for the new branch before synchronization completes.

## Git worktrees

Every worktree must have its own `.codegraph/` directory:

```text
~/work/project-main/.codegraph/
~/work/project-feature/.codegraph/
```

Initialize each worktree independently:

```bash
codegraph init ~/work/project-main
codegraph init ~/work/project-feature
```

Local testing created two real Git worktrees and initialized each separately.
The main worktree could not find a symbol that existed only on the feature
branch, while the feature worktree found it. Their index directories were
physically distinct.

Never copy or symlink `.codegraph/` from one worktree to another. A negative
fixture test showed that CodeGraph can accept a copied index without reporting a
worktree mismatch, so automatic mismatch detection must not be treated as a
safety boundary.

## Monorepos

Choose one indexing boundary deliberately.

### One index at the monorepo root

Use this when packages and services have meaningful cross-project calls or
imports:

```bash
codegraph init /absolute/path/to/monorepo
```

This gives CodeGraph one graph that can trace relationships across the whole
repository.

### Separate indexes for independent services

Use this when services are operationally independent or the whole monorepo is
too large:

```bash
codegraph init /absolute/path/to/monorepo/apps/api
codegraph init /absolute/path/to/monorepo/apps/web
```

Always pass the intended `projectPath` or `--path` when querying separate
indexes in one workspace.

Avoid overlapping root and child indexes by default. They duplicate CPU, disk,
and watcher work and make implicit project selection less obvious.

## CodeGraph and Graphify together

Both MCP servers may run at the same time because they use different names and
state directories. Use them for different strengths rather than sending every
question to both.

Prefer CodeGraph for:

- one-call source exploration;
- symbol and file lookup;
- call paths;
- caller/callee discovery;
- impact and affected-test analysis;
- continuously watched project indexes.

Prefer Graphify for:

- existing `graphify-out/graph.json` workflows;
- explicit graph traversal and community analysis;
- reports and exports already built around Graphify;
- repository workflows that require Graphify's graph schema.

Running both increases CPU, memory, disk use, and agent context. If one tool is
sufficient for a project, initialize only that tool there.

## Allowed operations

The following operations are supported and were validated locally where noted:

- **Allowed:** install CodeGraph through this Nix configuration.
- **Allowed:** initialize one independent `.codegraph/` index per project.
- **Allowed:** initialize each Git worktree independently.
- **Allowed:** run multiple CodeGraph MCP processes concurrently.
- **Allowed:** use CodeGraph and Graphify in the same project.
- **Allowed:** pass a project root or a nested path inside that project.
- **Allowed:** use explicit `projectPath`/`--path` to query another indexed
  project.
- **Allowed:** run `codegraph sync` after edits or branch operations.
- **Allowed:** run `codegraph index --force` to recover a stale or incompatible
  index.
- **Allowed:** run `codegraph telemetry off` if anonymous telemetry is not
  desired.
- **Allowed:** remove only a project's generated index with:

  ```bash
  codegraph uninit /absolute/path/to/project
  ```

## Prohibited operations

- **Prohibited:** do not run `codegraph install`. It imperatively edits agent
  configuration that Nix generates declaratively.
- **Prohibited:** do not run `codegraph uninstall` without `--keep-cli`. It may
  try to remove the Nix-managed executable and agent configuration. To remove
  this integration, edit the Nix module and rebuild.
- **Prohibited:** do not run `codegraph upgrade`. The executable lives in the
  immutable Nix store. Update the `llm-agents` flake input and rebuild instead.
- **Prohibited:** do not commit `.codegraph/` to Git.
- **Prohibited:** do not copy, move, or symlink `.codegraph/` between projects,
  branches checked out in different directories, worktrees, machines, Windows,
  and WSL.
- **Prohibited:** do not deliberately point one project at another project's
  `.codegraph/` database.
- **Prohibited:** do not assume `status.pendingChanges == 0` proves the index is
  current after a recent edit or branch switch; run `sync`.
- **Prohibited:** do not initialize overlapping monorepo root and child indexes
  without a documented reason.
- **Prohibited:** do not query both CodeGraph and Graphify automatically for
  every question; this duplicates work and consumes agent context.
- **Prohibited:** do not delete lock files manually. Use:

  ```bash
  codegraph unlock /absolute/path/to/project
  ```

  and only after confirming no active indexing process owns the lock.
- **Prohibited:** do not use an unfiltered `path:.` flake reference when ignored
  CodeGraph test indexes exist inside the checkout. CodeGraph may create a Unix
  `daemon.sock`, and Nix cannot archive socket files as a path flake source. Use
  the normal Git-backed flake reference (`.`), or keep disposable indexed
  projects outside the flake source tree.

## Recovery and troubleshooting

### Project is not initialized

Observed status output for an uninitialized fixture was non-destructive and
reported `initialized: false`.

Initialize it:

```bash
codegraph init /absolute/path/to/project
```

### Recent edits do not appear

```bash
codegraph sync /absolute/path/to/project
codegraph query SymbolName --path /absolute/path/to/project
```

### Large branch switch or suspected stale graph

```bash
codegraph index --force /absolute/path/to/project
codegraph status /absolute/path/to/project
```

### Stale lock

First close agents using that project. Then inspect running CodeGraph processes
before using:

```bash
codegraph unlock /absolute/path/to/project
```

### Slow or unreliable filesystem watcher

For WSL-mounted or slow network filesystems, start MCP with `--no-watch` and run
explicit synchronization. This is an exceptional configuration; the default
Nix-managed MCP server intentionally keeps watching enabled on local macOS
filesystems.

### Database locking

Healthy local indexes report:

```text
backend: node-sqlite
journalMode: wal
```

The local concurrency test produced no lock errors with multiple MCP processes.
If locking persists, stop all clients, run `codegraph status`, and rebuild the
index. Do not share an index across filesystem or OS boundaries.

## Tested commands and results

The following scenarios were exercised on the local test branch
`test/codegraph-local-validation-20260813`:

| Scenario | Result |
| --- | --- |
| Build `pkgs.llm-agents.codegraph` | Passed; version check reported 1.5.0 |
| Evaluate `m1-min` package and MCP settings | Passed |
| Generate Zed settings | CodeGraph present; Code Web Chat still absent |
| `nix flake check --no-build path:.` | Passed with pre-existing warnings |
| Initialize two independent projects | Passed; distinct WAL databases |
| Query project-specific symbols | Passed; no cross-project leakage |
| Query using a nested project path | Passed; owning index found upward |
| Explicit sync after source edit | Passed; changed file and new symbol indexed |
| Immediate `status.pendingChanges` after edit | Did not detect the edit; explicit sync did |
| Three concurrent MCP processes | Passed; all alive, no stderr or lock errors |
| MCP initialize and tool discovery | Passed; server `codegraph`, tool `codegraph_explore`, no stderr |
| Two independent Git worktrees | Passed; branch-specific symbols remained isolated |
| Copy an existing index to another directory | Accepted without mismatch warning; prohibited workflow |
| Initialize this repository | Passed; 223 files, 4,269 nodes, 4,803 edges in about 0.9s |
| `nix flake check --no-build path:.` with an ignored test index socket | Failed because Nix path sources cannot archive Unix sockets; use normal `.` evaluation |

Disposable fixture data and logs were kept under ignored `_ops/`. The real local
index is under ignored `.codegraph/`.
