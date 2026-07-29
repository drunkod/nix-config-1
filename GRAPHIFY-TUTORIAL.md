# Graphify: Correct Usage and Best Practices

This repository provides two supported Graphify environments:

1. the `m1-min` Nix/Home Manager installation on macOS;
2. a Nix-free `uv` launcher for Claude Code containers and sandboxes.

The central rule is simple:

> One Graphify MCP process must serve one explicit repository graph.

A Graphify graph is a snapshot stored in a project's own
`graphify-out/graph.json`. It is not a global database and should never silently
switch between repositories.

---

## What was fixed

The old MCP launcher could select a graph from another repository because it
mixed several sources of state:

- a globally saved graph path;
- the MCP process working directory;
- hard-coded fallback repositories.

The default `graphify` MCP server is now **fail-closed and project-scoped**.
Its automatic resolution order is:

1. `GRAPHIFY_GRAPH_PATH`, when explicitly provided;
2. `GRAPHIFY_PROJECT_ROOT`, when explicitly provided;
3. `graphify-out/graph.json` found by walking upward from the MCP process working directory;
4. otherwise, exit with an error.

Automatic startup never reads the saved global graph and never searches
unrelated fallback repositories.

Saved global selection still exists, but only through the explicitly named
`graphify-mcp-saved` command.

The `graphify-update` wrapper was also corrected. It now preserves the existing
`graph.json` and `manifest.json`, which are required for incremental updates.

---

## Commands installed by `m1-min`

| Command | Purpose |
| --- | --- |
| `graphify-extract <project>` | Create a fresh graph. Existing primary graph outputs are reset first. |
| `graphify-update <project>` | Incrementally refresh an existing graph without deleting it. |
| `graphify-query ... --graph <file>` | Query one explicitly named graph. |
| `graphify-mcp-auto` | Start MCP using only explicit environment/project context. |
| `graphify-mcp-find-graph` | Print the graph that automatic project discovery would use. |
| `graphify-mcp-run <project-or-graph>` | Start MCP for one explicit project or graph path. |
| `graphify-mcp-set-graph <project-or-graph>` | Save a graph for deliberate global use. |
| `graphify-mcp-saved` | Start MCP using only the deliberately saved graph. |
| `graphify-mcp` | Low-level upstream MCP executable wrapper. Prefer the safer wrappers above. |

---

## Apply the configuration on the M1 Mac

From the `nix-config` checkout:

```bash
cd ~/nix-config
nh darwin switch .#m1-min
```

Or with `darwin-rebuild`:

```bash
darwin-rebuild switch --flake ~/nix-config#m1-min
```

Open a new terminal after switching.

Clear any saved graph left by the previous implementation:

```bash
graphify-mcp-set-graph --clear
```

Then fully restart programmes that manage MCP servers. An already running MCP
process keeps the graph it received at startup.

---

## Normal project workflow

### 1. Enter the repository root

```bash
cd /path/to/project
```

Keep one `graphify-out/` directory per repository or worktree.

### 2. Create `.graphifyignore`

For local, deterministic code extraction, exclude prose, documents, media,
generated output, and dependencies.

A safe starting point is:

```gitignore
# Documentation and prose
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

# Office files, papers, and exported data
*.pdf
*.doc
*.docx
*.ppt
*.pptx
*.xls
*.xlsx
*.csv
*.tsv

# Images and media
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

# Dependencies and generated output
.graphify-src/
.graphify-runtime/
.venv/
venv/
graphify-out/
result/
node_modules/
dist/
build/
.cache/
coverage/
target/

# Project-specific documentation/assets
/docs/
/assets/
/screenshots/
```

Do not use an “ignore everything, then re-include extensions” pattern with
`!*/`. The Graphify version pinned by this configuration has not handled that
pattern reliably for this offline workflow.

### 3. Create the first graph

With the installed command:

```bash
graphify-extract .
```

Or explicitly through the flake:

```bash
nix run ~/nix-config#graphify-extract -- .
```

A healthy offline run reports code files and zero documents, papers, and images:

```text
found 54 code, 0 docs, 0 papers, 0 images
```

Expected primary output:

```text
graphify-out/graph.json
graphify-out/manifest.json
```

### 4. Query one explicit graph

```bash
graphify-query \
  "what depends on RuntimeBridge" \
  --graph "$PWD/graphify-out/graph.json"
```

Prefer concrete names from the codebase: files, modules, classes, functions,
packages, or services. For broad architecture work, inspect
`GRAPH_REPORT.md` when available and then run narrower graph queries.

### 5. Refresh after edits

```bash
graphify-update .
```

Use `graphify-update` only after the first graph exists. It now preserves the
existing graph and performs an incremental refresh.

Run a fresh extraction instead when:

- the graph is corrupt;
- ignore rules changed substantially;
- the repository was replaced with unrelated content;
- an update reports that required graph state is missing.

---

## Safe MCP modes

### Mode A: project-scoped automatic discovery

This is the default system MCP command:

```bash
graphify-mcp-auto
```

Test what it will select before starting the server:

```bash
graphify-mcp-find-graph
```

The command prints the selected path to standard output and reports the source
of the selection to standard error, for example:

```text
graphify MCP: selected graph via workspace search: /path/to/project/graphify-out/graph.json
```

Use automatic mode only when the launching programme starts MCP with the
repository, or a child directory of it, as its working directory.

If no project graph is available, startup fails. That failure is intentional:
it is safer than serving another repository.

### Mode B: explicit fixed graph — recommended for GUI programmes

GUI applications do not always preserve the project working directory. Give
them an absolute graph path:

```bash
graphify-mcp-run \
  /Users/test/Documents/work/example/graphify-out/graph.json
```

A project directory is also accepted:

```bash
graphify-mcp-run /Users/test/Documents/work/example
```

This is the recommended mode for Claude Code project configuration, Zed, and
any programme that may launch MCP from `$HOME` or another generic directory.

### Mode C: explicit saved global graph

Use this only when a programme cannot supply a project path and you deliberately
want one global selection.

Save a graph:

```bash
graphify-mcp-set-graph /Users/test/Documents/work/example
```

Inspect it:

```bash
graphify-mcp-set-graph --show
```

Start the explicitly saved server:

```bash
graphify-mcp-saved
```

Clear it:

```bash
graphify-mcp-set-graph --clear
```

`graphify-mcp-auto` never reads this saved state.

---

## Claude Code on the `m1-min` system

For a repository-specific MCP configuration, first locate the installed wrapper:

```bash
command -v graphify-mcp-run
```

Use that absolute command path and the absolute graph path in the project's
`.mcp.json`:

```json
{
  "mcpServers": {
    "graphify": {
      "command": "/Users/test/.nix-profile/bin/graphify-mcp-run",
      "args": [
        "/Users/test/Documents/work/example/graphify-out/graph.json"
      ]
    }
  }
}
```

Replace both example paths with the values from your machine. Do not rely on
`~`, `$HOME`, or the client's working directory inside JSON configuration.

Before launching Claude Code for that repository:

```bash
cd /Users/test/Documents/work/example
graphify-update .
claude
```

For a new repository, run `graphify-extract .` instead of `graphify-update .`.

### When automatic mode is acceptable

A project may configure `graphify-mcp-auto` instead of `graphify-mcp-run` only
when Claude Code is always launched from that repository and preserves its
working directory. Fixed-path mode remains safer and easier to diagnose.

---

## Claude Code sandbox without Nix

The repository includes:

```text
scripts/graphify-sandbox.sh
```

It uses `uv` to create a private Python environment and installs the same pinned
Graphify revision as `flake.lock`. It does not require Nix and does not use the
Mac's saved MCP state.

### Sandbox requirements

The sandbox needs:

- Bash;
- Git when the source must be downloaded;
- `uv`;
- a Python version supported by the pinned Graphify source;
- network access to the source repository, or a mounted Graphify source checkout.

Invoke the script with `bash`; its executable bit may not survive every archive,
mount, or sandbox transfer.

### Network-enabled sandbox

From the target project:

```bash
cd /workspace/project
bash /workspace/nix-config/scripts/graphify-sandbox.sh extract .
```

The first invocation fetches the pinned source and creates a cached runtime.
Later invocations reuse it.

Query the graph:

```bash
bash /workspace/nix-config/scripts/graphify-sandbox.sh query \
  "what calls RuntimeBridge" \
  --graph /workspace/project/graphify-out/graph.json
```

Refresh after edits:

```bash
bash /workspace/nix-config/scripts/graphify-sandbox.sh update \
  /workspace/project
```

Start MCP with an explicit graph:

```bash
bash /workspace/nix-config/scripts/graphify-sandbox.sh mcp \
  /workspace/project/graphify-out/graph.json
```

### Offline or network-restricted sandbox

Mount or copy the pinned Graphify source into the sandbox, then set
`GRAPHIFY_SOURCE_DIR`:

```bash
export GRAPHIFY_SOURCE_DIR=/workspace/vendor/graphify

bash /workspace/nix-config/scripts/graphify-sandbox.sh extract \
  /workspace/project
```

The source directory must contain Graphify's `pyproject.toml` and package source.
No network access is needed once the Python dependencies are available in the
sandbox's package cache or mirror.

### Claude Code `.mcp.json` in a sandbox

Use an explicit graph path:

```json
{
  "mcpServers": {
    "graphify": {
      "command": "bash",
      "args": [
        "/workspace/nix-config/scripts/graphify-sandbox.sh",
        "mcp",
        "/workspace/project/graphify-out/graph.json"
      ],
      "env": {
        "GRAPHIFY_SANDBOX_STATE_DIR": "/workspace/.cache/graphify-sandbox"
      }
    }
  }
}
```

For an offline sandbox, add the mounted source directory to the environment:

```json
{
  "mcpServers": {
    "graphify": {
      "command": "bash",
      "args": [
        "/workspace/nix-config/scripts/graphify-sandbox.sh",
        "mcp",
        "/workspace/project/graphify-out/graph.json"
      ],
      "env": {
        "GRAPHIFY_SOURCE_DIR": "/workspace/vendor/graphify",
        "GRAPHIFY_SANDBOX_STATE_DIR": "/workspace/.cache/graphify-sandbox"
      }
    }
  }
}
```

Each sandbox or repository should name its own graph explicitly. Do not copy a
saved graph-path state file between sandboxes.

---

## Runtime and extras

The Nix wrapper and sandbox wrapper default to these lightweight code-oriented
extras:

```text
mcp,watch,svg,sql,terraform
```

Heavier document, office, media, database, or model-provider extras must be
requested explicitly. For example:

```bash
export GRAPHIFY_UV_EXTRAS=mcp,pdf,office
```

Changing `GRAPHIFY_UV_EXTRAS` now changes the runtime installation identity, so
the wrapper recreates the environment instead of silently reusing an
incompatible installation.

For private, offline code analysis, keep the corpus code-only and do not add
model-provider extras or API keys.

---

## Diagnosing graph selection

### Check automatic selection

```bash
graphify-mcp-find-graph
```

### Force one graph for a single process

```bash
GRAPHIFY_GRAPH_PATH=/absolute/project/graphify-out/graph.json \
  graphify-mcp-auto
```

An invalid `GRAPHIFY_GRAPH_PATH` fails immediately. It does not fall back to the
working directory.

### Force one project root for a single process

```bash
GRAPHIFY_PROJECT_ROOT=/absolute/project \
  graphify-mcp-auto
```

### Inspect or remove explicit saved state

```bash
graphify-mcp-set-graph --show
graphify-mcp-set-graph --clear
```

Remember that saved state is ignored by automatic mode.

---

## Troubleshooting

### `graphify MCP: no project graph found`

Create the graph in the target repository:

```bash
cd /path/to/project
graphify-extract .
```

For GUI clients, configure `graphify-mcp-run` with an absolute graph path.

### The server still shows old repository data

1. Confirm the configured absolute graph path.
2. Run `graphify-mcp-find-graph` when using automatic mode.
3. Refresh the target graph with `graphify-update .`.
4. Fully restart the programme's MCP server process.

The new automatic launcher does not read saved global state. If the wrong data
still appears, the programme is normally reusing an old MCP process or its
configuration points to the wrong explicit file.

### `graphify-update` says graph state is missing

Run a fresh extraction once:

```bash
graphify-extract .
```

Then use `graphify-update .` after subsequent edits.

### `no LLM API key found`

The corpus contains documents, papers, images, or other semantic inputs. Tighten
`.graphifyignore` until extraction reports zero non-code categories.

### Reset the Nix-managed Python runtime

The runtime contains no project graph data and can be recreated:

```bash
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/graphify-nix"
```

The next Graphify command reinstalls the pinned source.

### Reset the sandbox runtime

```bash
rm -rf "${GRAPHIFY_SANDBOX_STATE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/graphify-sandbox}"
```

Project graphs under `graphify-out/` are separate and are not removed by these
runtime resets.

---

## Best-practice checklist

- Keep `graphify-out/graph.json` inside the repository or worktree it describes.
- Run the first build with `graphify-extract`; use `graphify-update` after edits.
- Pass `--graph` explicitly for CLI queries.
- Use `graphify-mcp-run` with an absolute path for GUI and project MCP configuration.
- Use `graphify-mcp-auto` only when the client reliably preserves the project working directory.
- Treat `graphify-mcp-saved` as a deliberate single-project global mode, not automatic discovery.
- Restart the MCP process after changing or rebuilding a graph.
- Keep `.graphifyignore` code-only for local deterministic extraction.
- Never share one mutable saved graph path across unrelated repositories or sandboxes.
