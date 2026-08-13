# 1. Onboard a repository into Repo Harness

Use this guide when you have a Git repository on the `m1-min` Mac and want
Repo Harness to read or modify it through the existing Coding MCP service.
Shared rules: [`Repo Harness safety`](../safety.md).

This guide is the default starting point. Do not begin with the Browser Engine,
named Cloudflare tunnels, Graphify, or the full strict workflow. Initialize
CodeGraph only after adoption by continuing to guide 2.

## The two repositories have different jobs

| Repository | Authority |
|---|---|
| `drunkod/repo-harness` | Repo Harness CLI, repository contract, MCP protocol, workspace and security behavior |
| `drunkod/nix-config-1` | Installation and operation on this Mac: launchd, loopback port, Quick Tunnel, OAuth helper, aliases |

The workflow documented here was tested with:

```text
repo-harness: 1789a75100bc767c991104c32df39478ff3bbf32
nix-config:    branch agent/repo-harness-coding-mcp-m1-min
```

`rh-bootstrap` currently installs the moving Repo Harness branch
`agent/chatgpt-github-create-mvp`, not that exact SHA. `repo-harness --version`
reports package version `0.12.0` but does not prove source identity. Before
re-bootstrapping, inspect the upstream branch and treat behavior beyond the
tested SHA as a new version requiring the onboarding and MCP checks again.

## Terminology that must not be mixed

| Term | Meaning |
|---|---|
| Host install `minimal` / `full` | Which global Repo Harness host adapters are installed |
| Repository adoption `minimal` / `standard` / `self-host` | How much repo-local workflow structure `repo-harness init` creates |
| Workflow `Lite` / `Standard` / `Strict` | How much process a particular task requires |
| MCP `planner` / `coding` | Whether ChatGPT can plan/read or can also open workspaces, edit, and run commands |
| CodeGraph / Graphify | Optional code-navigation indexes; neither grants filesystem access |

For this Mac, Nix owns the host integration. Do not run the upstream global
installer over Nix-managed Claude, Codex, or editor configuration.

## Prerequisites

Verify the `m1-min` host first:

```bash
cd ~/nix-config
repo-harness --version
repo-harness-mcp-health
```

If the CLI is missing or stale:

```bash
rh-bootstrap
repo-harness --version
```

If the Nix helpers are missing, activate the `m1-min` configuration before
continuing. See the [`m1-min` Coding MCP reference](../reference/m1-min-coding-mcp.md).

## Step 1: prepare the target repository

Clone or create the repository normally:

```bash
git clone https://github.com/OWNER/REPOSITORY.git ~/src/REPOSITORY
cd ~/src/REPOSITORY
```

For a newly created local project, initialize Git but do not broadly stage or
commit yet:

```bash
git init
git status --short --branch
```

First create a project-appropriate `.gitignore` and review every untracked path.
Stage explicit reviewed paths:

```bash
git add README.md .gitignore path/to/reviewed/source
git diff --cached --stat
git diff --cached
git commit -m "chore: initialize repository"
```

Managed workspaces need a real base commit, but safety review comes before that
commit.

Check an existing repository before granting access:

```bash
git status --short --branch
git rev-parse --show-toplevel
git rev-parse HEAD
```


## Step 2: define the read boundary

Repo Harness general repository reads use `.ignore` as a content boundary.
`.gitignore`, hidden-file status, file extensions, CodeGraph, and Graphify are
not authorization boundaries.

Create or review `.ignore` before registration. At minimum, exclude repository-
specific secrets and private operational state, for example:

```gitignore
.env
.env.*
*.pem
*.key
secrets/
_ops/
.repo-harness/
```

Adapt this sample to the project. The shared safety guide explains why
`.gitignore` and code indexes do not replace `.ignore`.

## Step 3: preview repository adoption

Always preview first:

```bash
repo-harness init \
  --repo "$PWD" \
  --mode standard \
  --no-codegraph \
  --dry-run
```

Use `standard` for a repository that should fully participate in Repo Harness.
Review the complete operation list before applying it.

If standard adoption is too large and the immediate goal is only the Coding MCP
MVP, preview bounded minimal adoption instead:

```bash
repo-harness init \
  --repo "$PWD" \
  --mode minimal \
  --no-codegraph \
  --dry-run
```

Important: on Repo Harness `0.12.0` at the tested revision, minimal adoption
creates a valid `.ai/harness/workflow-contract.json` but its final strict
workflow verification can fail because minimal mode omits files required by the
full strict checker. Minimal adoption can enable MCP without claiming full
strict workflow compliance.

## Step 4: apply and review adoption

Important: applying `repo-harness init` automatically registers the repository
as `read_only`. That read registration occurs before you commit the generated
adoption files. If an already-authorized connector is running, assume the
repository may become discoverable immediately after `init` succeeds.

Therefore, complete `.ignore` review before applying initialization.

For the normal full repository contract:

```bash
repo-harness init \
  --repo "$PWD" \
  --mode standard \
  --no-codegraph
```

For the bounded MCP-first contract:

```bash
repo-harness init \
  --repo "$PWD" \
  --mode minimal \
  --no-codegraph
```

Minimal adoption derives the initial `docs/spec.md` product title from the target
directory name. When adoption runs in a disposable worktree, review and correct
that generated title before committing it.

Then inspect what was created:

```bash
git status --short
git diff --stat
git diff
repo-harness status --json
repo-harness state resolve --json
```

Require `repo-harness status --json` to report:

```text
repo.optIn = true
repo.optInMarker = .ai/harness/workflow-contract.json
```

Do not copy only the marker. Keep the generated contract and its required
scaffolding together.

## Step 5: commit adoption before opening workspaces

The exact base commit used by `open_workspace` must contain the adoption files.
A worktree opened from a pre-adoption commit is not adopted.

Commit the reviewed adoption on a branch. Stage the explicit reviewed paths;
do not use `git add -A` when unrelated local state exists:

```bash
git switch -c chore/adopt-repo-harness
git add -- .gitignore .ignore .ai docs/spec.md plans tasks
git diff --cached --check
git commit -m "chore: adopt repo-harness workflow"
```

For a long-lived feature branch, create an isolated adoption worktree from the
feature branch's exact SHA. After committing adoption there, verify it is a
direct descendant and fast-forward the original feature branch with
`git merge --ff-only <adoption-sha>`. Do not mix adoption into a different base,
force-push, or copy `.ai` files manually.

For standard adoption, verify a fresh detached worktree:

```bash
git worktree add --detach ../REPOSITORY-adoption-check HEAD
env -C ../REPOSITORY-adoption-check \
  repo-harness run check-task-workflow --strict
git worktree remove ../REPOSITORY-adoption-check
```

For minimal adoption, record the known strict-check failure rather than claiming
it passed.

### Build context after adoption

After adoption is committed, use the
[context-packet recipe](../../developer-recipes/01-context-packet.md). It owns the
Gitingest, CodeGraph, Graphify, ChatGPT-surface, and cleanup steps.

## Step 6: choose access mode

After `init`, confirm or explicitly reset the automatic registration to
read-only unless ChatGPT must modify source:

```bash
repo-harness mcp access set \
  --repo "$PWD" \
  --mode read_only \
  --json
```

Enable Coding MCP writes only after adoption has been reviewed and committed:

```bash
repo-harness mcp access set \
  --repo "$PWD" \
  --mode read_write \
  --json
```

To remove write authority later, downgrade it:

```bash
repo-harness mcp access set \
  --repo "$PWD" \
  --mode read_only \
  --json
```

Do not grant `/`, `/Users/test`, `~/src`, `/tmp`, or another parent containing
multiple projects. Grant one canonical Git repository path at a time.

## Step 7: record the authorization change

Repository access changes advance the authorization revision. Existing OAuth
sessions are then stale by design.

Do not start or replace the tunnel in this onboarding guide. Record the returned
`authorizationRevision`, continue to CodeGraph initialization in guide 2, then
refresh the MCP setup and ChatGPT OAuth in guide 3.

## Step 8: initialize optional indexes

Only after repository access works should you add code indexes.

- Continue with [guide 2: initialize CodeGraph](02-initialize-codegraph.md).
- CodeGraph is installed declaratively by `nix-config`; do not run imperative
  `codegraph install` or `codegraph upgrade` over it.
- Graphify uses one separate graph per repository/worktree. Follow
  [`graphify-new-repository.md`](../../tools/graphify.md).
- Neither tool grants Repo Harness access or replaces `.ignore` and path checks.

## Onboarding completion checklist

```text
[ ] repository has a clean committed base
[ ] .ignore excludes sensitive content
[ ] adoption preview was reviewed
[ ] repository was safe for automatic read_only registration before init
[ ] adoption files are committed
[ ] repo-harness status reports optIn=true
[ ] exact repository path has read_only or read_write access
[ ] latest authorization revision was recorded for guide 3
[ ] exact adoption commit SHA is available for open_workspace
```

Continue with [guide 2: initialize CodeGraph](02-initialize-codegraph.md).
