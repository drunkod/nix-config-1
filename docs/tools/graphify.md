# Graphify workflow for `m1-min`

[Code-intelligence tools](README.md) · [Documentation index](../README.md)

This is the canonical Graphify guide for this repository. It reflects the
current Nix implementation and the Graphify revision pinned by `flake.lock`:

```text
0b2bd938c4a48e91d27f0ba09b96409e0a36c78a
```

The default host profile is `m1-min` on `aarch64-darwin`.

## Architecture

The `m1-min` profile imports both `graphify` and `mcp`:

- `modules/programs/graphify.nix` installs the CLI wrappers and exposes flake
  apps/packages;
- `nix/graphify.nix` defines the pinned Python runtime and safe wrappers;
- `modules/programs/mcp.nix` registers `graphify-mcp-auto` in the shared MCP
  registry;
- Claude Code, Codex, and Zed consume that registry;
- `scripts/graphify-sandbox.sh` provides the same pinned source revision for
  Nix-free containers and sandboxes.

Graphify source is copied from the locked flake input into a user-writable `uv`
venv on first use. The default runtime identity includes:

```text
extras: mcp,watch,svg,sql,terraform
MCP SDK: 1.26.0
```

Changing the locked source, extras, or MCP SDK identity causes the wrapper to
recreate the runtime under:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/graphify-nix
```

Project graphs are separate from this runtime and live under each project:

```text
<project>/graphify-out/graph.json
<project>/graphify-out/manifest.json
```

## Safety invariant

> One query or MCP process must use one identified graph from one repository or
> worktree.

Do not treat Graphify as one mutable global database. Keep a separate
`graphify-out/` directory for every repository and every Git worktree.

## Apply `m1-min`

From this checkout:

```bash
nh darwin switch .#m1-min
```

Equivalent command without `nh`:

```bash
darwin-rebuild switch --flake ~/nix-config#m1-min
```

Open a new terminal and restart Claude Code, Codex, and Zed after switching.
Existing MCP processes keep the graph they opened at startup.

Verify the installed commands:

```bash
command -v graphify
command -v graphify-extract
command -v graphify-update
command -v graphify-query
command -v graphify-mcp-find-graph
command -v graphify-mcp-run
```

## Installed commands

| Command | Supported purpose |
| --- | --- |
| `graphify` | Pinned upstream CLI. Check `graphify --help` before advanced/version-sensitive use. |
| `graphify-extract <project>` | Fresh extraction. Deletes only the target's existing `graph.json` and `manifest.json`, then runs `extract --no-cluster`. |
| `graphify-update <project>` | Code refresh that preserves existing graph state and runs `update --no-cluster`. |
| `graphify-query ... --graph <file>` | Query one explicit graph. |
| `graphify-mcp-find-graph` | Show what automatic MCP discovery selects. |
| `graphify-mcp-auto` | Default MCP server; fail-closed project selection. |
| `graphify-mcp-run <project-or-graph>` | Start MCP for one explicit graph. |
| `graphify-mcp-set-graph` | Manage deliberate saved state. |
| `graphify-mcp-saved` | Start MCP from deliberate saved state only. |
| `graphify-mcp` | Low-level executable; prefer safe wrappers. |

The same commands are exposed as flake apps, for example:

```bash
nix run ~/nix-config#graphify-extract -- /absolute/project --code-only
nix run ~/nix-config#graphify-update -- /absolute/project
nix run ~/nix-config#graphify-query -- \
  "UserService main" \
  --graph /absolute/project/graphify-out/graph.json
```

## Prepare a project

### Add `.graphifyignore`

The default `m1-min` workflow is deterministic, local, code-only extraction.
Exclude prose, media, dependencies, generated trees, and Graphify output:

```gitignore
# Graphify output and local runtimes
graphify-out/
.graphify-src/
.graphify-runtime/
.venv/
venv/

# Dependencies and generated output
node_modules/
result/
dist/
build/
target/
.cache/
coverage/

# Prose and structured documents
*.md
*.mdx
*.rst
*.adoc
*.asciidoc
*.org
*.txt
*.rtf
*.tex
*.html
*.htm
*.yaml
*.yml
*.csv
*.tsv

# Office files and papers
*.pdf
*.doc
*.docx
*.ppt
*.pptx
*.xls
*.xlsx

# Images, audio, and video
*.png
*.jpg
*.jpeg
*.gif
*.webp
*.bmp
*.tif
*.tiff
*.svg
*.ico
*.mp3
*.wav
*.ogg
*.mp4
*.mov
*.avi
*.mkv

# Project-specific non-code trees
docs/
assets/
images/
screenshots/
```

Do not use an ignore-everything/re-include pattern such as `*`, `!*/`, and
`!*.py`. Use direct exclusions; they are easier to audit and have behaved more
reliably with the pinned workflow.

### Create the first graph

Use the explicit code-only flag on initial extraction:

```bash
graphify-extract /absolute/path/to/project --code-only
```

From the project root, this is equivalent:

```bash
graphify-extract . --code-only
```

A healthy local extraction reports zero semantic inputs:

```text
found N code, 0 docs, 0 papers, 0 images
```

Verify the outputs:

```bash
test -s graphify-out/graph.json
test -s graphify-out/manifest.json
```

The extract wrapper is intentionally destructive only to the two primary graph
state files. Use it for first creation or a deliberate clean rebuild.

### Update after code changes

```bash
graphify-update /absolute/path/to/project
```

Do not pass `--code-only` to `graphify-update`; the pinned `update` command does
not support that option. `update` is already the local code refresh path.

Use `--force` only after a large deletion/refactor when accepting fewer nodes is
intentional:

```bash
graphify-update /absolute/path/to/project --force
```

Use a fresh extraction instead when:

- `graph.json` or `manifest.json` is missing or corrupt;
- `.graphifyignore` changed substantially;
- the directory now contains an unrelated project;
- the CLI reports an old node-ID scheme and requests a force rebuild.

For a clean path-qualified-ID rebuild:

```bash
graphify-extract /absolute/path/to/project --code-only --force
```

## Query workflow

Always pass the graph explicitly for CLI queries:

```bash
graphify-query \
  "UserService main repository" \
  --graph /absolute/project/graphify-out/graph.json \
  --budget 2000
```

Use concrete vocabulary from source: file names, functions, classes, packages,
services, and relationships. The current CLI also supports:

```bash
graphify path "Node A" "Node B" --graph /absolute/project/graphify-out/graph.json
graphify explain "Node A" --graph /absolute/project/graphify-out/graph.json
graphify affected "Node A" --graph /absolute/project/graphify-out/graph.json
graphify god-nodes --graph /absolute/project/graphify-out/graph.json --json
```

Do not invoke `graphify-out/.graphify_python` or manually reproduce Graphify's
internal detection, extraction, merge, manifest, or clustering pipeline.

## Default MCP behavior on `m1-min`

The shared registry launches:

```bash
graphify-mcp-auto
```

Automatic selection resolves in this exact order:

1. valid `GRAPHIFY_GRAPH_PATH`;
2. valid `GRAPHIFY_PROJECT_ROOT` containing `graphify-out/graph.json`;
3. the nearest Git repository root, then exactly
   `<git-root>/graphify-out/graph.json`;
4. failure.

Important details:

- it does not scan arbitrary parent directories for graphs;
- it never climbs above the nearest Git root;
- it fails outside Git unless an explicit environment variable is set;
- an invalid explicit variable fails immediately;
- it never reads saved global state;
- it never searches hard-coded fallback repositories.

Inspect automatic selection from the same working directory the client uses:

```bash
graphify-mcp-find-graph
```

A healthy result identifies its source:

```text
graphify MCP: selected graph via Git repository root: /path/project/graphify-out/graph.json
```

Failure is safer than serving another repository.

### GUI and multi-root workspaces

Zed and other GUI clients may not launch MCP from the expected repository root.
The global `m1-min` registry still uses fail-closed automatic mode, so Graphify
may be unavailable rather than selecting a wrong graph.

For a durable project-specific configuration, use an explicit graph:

```bash
graphify-mcp-run /absolute/project/graphify-out/graph.json
```

A project directory is also accepted:

```bash
graphify-mcp-run /absolute/project
```

Do not add an imperative global installer on top of Nix-managed Claude, Codex,
or Zed configuration. Add a project-local override only when the client cannot
provide reliable project context.

### Saved mode

Saved state is an explicit exceptional mode, not project discovery:

```bash
graphify-mcp-set-graph /absolute/project
graphify-mcp-set-graph --show
graphify-mcp-saved
graphify-mcp-set-graph --clear
```

`graphify-mcp-auto` ignores this state. Do not use saved mode to switch among
projects automatically.

## Git branches and worktrees

### Branch switch in one checkout

The graph remains in the same directory. Refresh after switching:

```bash
git switch feature/example
graphify-update .
```

Use a fresh force extraction when the branch has substantially different source
or when Graphify recommends a node-ID rebuild.

### Git worktrees

Each worktree must own its graph:

```text
~/work/project-main/graphify-out/
~/work/project-feature/graphify-out/
```

Initialize each independently. Never symlink or copy one mutable
`graphify-out/` between worktrees.

## MCP tools verified locally

A protocol-level test against `graphify-mcp-run` successfully initialized the
server and listed:

- `query_graph`;
- `get_node`;
- `get_neighbors`;
- `get_community`;
- `god_nodes`;
- `graph_stats`;
- `shortest_path`;
- `list_prs`;
- `get_pr_impact`;
- `triage_prs`.

The GitHub/PR tools may require repository and network context. Use graph-only
tools for local offline traversal.

## Graphify and CodeGraph

Both are installed by `m1-min` and can coexist because they use separate state
and MCP names:

| Tool | State | Best default use |
| --- | --- | --- |
| CodeGraph | `.codegraph/` SQLite index | Fast source/symbol exploration with automatic file watching. |
| Graphify | `graphify-out/graph.json` snapshot | Explicit graph traversal, communities, exports, and Graphify-specific analysis. |

Do not send every question to both tools. Prefer one primary tool per task to
avoid duplicate CPU, disk, and context usage.

## Optional features

These are not part of the default code-only workflow. Check `graphify --help`
before use.

### Clustering and reports

The safe wrappers use `--no-cluster`. To cluster an existing graph without LLM
community naming:

```bash
graphify cluster-only /absolute/project --no-label
```

Community naming can require a model provider and is opt-in.

### Hooks and watch mode

```bash
graphify hook status
graphify hook install
graphify hook uninstall
graphify watch /absolute/project
```

Hooks modify the target repository. Install them only on explicit request and
inspect existing hooks first. Watch is a foreground process.

### Exports

The pinned root help advertises:

```bash
graphify export callflow-html --output /absolute/path/to/callflow.html
graphify tree \
  --graph /absolute/project/graphify-out/graph.json \
  --output /absolute/project/graphify-out/GRAPH_TREE.html
```

Do not document or run unadvertised export formats based on older upstream
examples.

### Documents, URLs, media, databases, and semantic extraction

These can require network access, API keys, external services, heavier extras,
and data disclosure to model providers. Use them only when explicitly requested.
For private local code work, retain `--code-only` and zero semantic inputs.

## Nix-free sandbox

Use:

```bash
bash /workspace/nix-config/scripts/graphify-sandbox.sh extract /workspace/project --code-only
bash /workspace/nix-config/scripts/graphify-sandbox.sh update /workspace/project
bash /workspace/nix-config/scripts/graphify-sandbox.sh query \
  "UserService main" \
  --graph /workspace/project/graphify-out/graph.json
bash /workspace/nix-config/scripts/graphify-sandbox.sh mcp \
  /workspace/project/graphify-out/graph.json
```

The script's default revision is checked against `inputs.graphify-src.rev` by
the flake check. For an offline sandbox, mount the locked source and set:

```bash
export GRAPHIFY_SOURCE_DIR=/workspace/vendor/graphify
```

Never copy saved MCP state or a mutable project graph between the Mac and a
sandbox.

## Allowed

- one `graphify-out/` per repository/worktree;
- `graphify-extract <project> --code-only` for first build/clean rebuild;
- `graphify-update <project>` after code edits;
- explicit `--graph` for CLI queries;
- `graphify-mcp-find-graph` before relying on automatic mode;
- `graphify-mcp-run` for explicit GUI/project configuration;
- multiple MCP processes when each receives the intended graph;
- Graphify and CodeGraph in the same project when their roles are deliberate;
- semantic features only after explicit approval of network, credentials,
  privacy, and dependency implications.

## Prohibited

- do not run `graphify-update --code-only`;
- do not delete `graph.json` or `manifest.json` before an incremental update;
- do not share or symlink `graphify-out/` between projects/worktrees;
- do not let automatic mode use ambiguous GUI working-directory context;
- do not treat saved state as automatic project selection;
- do not invoke `graphify-out/.graphify_python`;
- do not manually implement internal extraction/merge pipelines from old docs;
- do not run `graphify install`, `graphify claude install`, or similar
  imperative agent installers over Nix-managed global configuration;
- do not enable document/media/semantic extras or transmit project content
  without explicit user approval;
- do not use `GRAPHIFY_UV_EXTRAS=all` by default.

## Recovery

Check the selected graph:

```bash
graphify-mcp-find-graph
```

Refresh code:

```bash
graphify-update /absolute/project
```

Clean rebuild:

```bash
graphify-extract /absolute/project --code-only --force
```

Reset only the Nix-managed Python runtime:

```bash
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/graphify-nix"
```

This does not remove project graphs. The next command reinstalls the locked
source.

If an MCP client still shows old data, refresh the graph and fully restart that
client's MCP process.

## Local validation results

The following were tested on `test/codegraph-local-validation-20260813` with the
current lock:

| Scenario | Result |
| --- | --- |
| Evaluate `m1-min` Graphify MCP command | `graphify-mcp-auto` selected from the Nix store |
| Evaluate installed Graphify packages | All CLI/MCP wrappers present once after refactor |
| Wrapper flake check | Passed |
| Fresh code-only extraction | 2 code, 0 docs/papers/images; 8 nodes, 13 edges |
| Explicit query | Returned the fixture's classes, methods, imports, and calls |
| `god-nodes --json` | Returned fixture architectural hubs |
| Code update | Preserved graph files and rebuilt 8 nodes, 13 edges |
| `graphify-update --code-only` | Rejected as unsupported; documented as prohibited |
| Git-root automatic selection | Selected exactly `<git-root>/graphify-out/graph.json` |
| Non-Git automatic selection | Failed closed without explicit environment context |
| Invalid `GRAPHIFY_GRAPH_PATH` | Failed closed without fallback |
| Explicit MCP protocol handshake | Passed; ten tools listed, no server error |
