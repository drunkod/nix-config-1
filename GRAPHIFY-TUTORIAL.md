# Graphify Tutorial

This tutorial explains how to use the Graphify integration in this `nix-config`, how to keep it fully offline, and how to create a working `.graphifyignore` file for new projects.

---

## What is already configured

This repository exposes Graphify through flake apps and shell aliases.

Available flake apps:

- `graphify-extract`
- `graphify-update`
- `graphify-query`
- `graphify-mcp`
- `graphify-skill`

Available dev shell:

- `nix develop <nix-config-flake>#graphify`

If your shell configuration from this repo is applied, you may also have these aliases:

- `graphify-extract`
- `graphify-update`
- `graphify-query`
- `graphify-mcp`
- `graphify-shell`

This Graphify setup is designed for **offline, code-only extraction**:

- no API key
- no LLM backend
- deterministic tree-sitter extraction
- `.graphifyignore` used to exclude docs, papers, images, and generated files

---

## Find your `nix-config` flake path

Most commands below refer to `<nix-config-flake>`.

Use one of these:

- your actual checkout path, for example `~/nix-config`
- `~/.setup` if that is where you cloned it

Examples in this tutorial will use:

```bash
~/nix-config
```

If your repo lives elsewhere, replace that path in the examples.

---

## Basic workflow

### 1. Enter the target project

```bash
cd /path/to/project
```

### 2. Create a `.graphifyignore`

Before extracting a graph, make the corpus code-only.

Minimal safe starting point:

```gitignore
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
*.pdf
*.doc
*.docx
*.ppt
*.pptx
*.xls
*.xlsx
*.csv
*.tsv
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

graphify-out/
.venv/
venv/
node_modules/
dist/
build/
result/
docs/
```

### 3. Build the graph

If your aliases are available:

```bash
graphify-extract
```

Or explicitly through the flake:

```bash
nix run ~/nix-config#graphify-extract -- .
```

### 4. Check the output

```bash
ls graphify-out
```

Expected files:

- `graph.json`
- `manifest.json`

### 5. Query the graph

Using the alias:

```bash
graphify-query "what depends on auth"
```

Or explicitly:

```bash
nix run ~/nix-config#graphify-query -- "what depends on auth" --graph ./graphify-out/graph.json
```

### 6. Refresh after edits

```bash
graphify-update
```

Or:

```bash
nix run ~/nix-config#graphify-update -- .
```

---

## How to verify offline mode is working

A successful offline extraction should say that it found only code files.

Good output looks like this:

```text
[graphify extract] found 54 code, 0 docs, 0 papers, 0 images
```

If you see non-zero docs, papers, or images, Graphify may require an API key and the extraction will stop.

For example, this means your `.graphifyignore` still needs work:

```text
[graphify extract] found 846 code, 1011 docs, 2 papers, 65 images
error: no LLM API key found
```

In that case, add more ignore patterns and run extraction again.

---

## How to create a good `.graphifyignore`

### Recommended strategy

Use a **deny non-code content** strategy.

Do **not** use this style:

```gitignore
*
!*/
!*.py
!*.nix
!*.js
```

In the Graphify version used here, the `!*/` re-include pattern is not reliable enough for this use case and can accidentally let docs back into the corpus.

### Use this strategy instead

Explicitly exclude:

- docs / prose
- office files
- papers
- images / media
- generated files
- local build artifacts
- vendored dependency trees

### Good reusable template

```gitignore
# Docs / prose
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

# Papers / office / exported data
*.pdf
*.doc
*.docx
*.ppt
*.pptx
*.xls
*.xlsx
*.csv
*.tsv

# Images / media
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

# Generated / local / vendor
.graphify-src/
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

# Project docs
/docs/
```

---

## How to generate a `.graphifyignore` for a new project

### Option A: Start from the template

1. copy the reusable template above
2. add project-specific generated directories
3. add project-specific docs/assets folders
4. run extraction
5. tighten the ignore file if docs/images still appear

### Option B: Inspect the project first

Useful commands:

```bash
find . -maxdepth 2 -type d | sort
find . -type f | sed 's|.*\.||' | sort | uniq -c | sort -n
```

Look for:

- `docs/`
- `assets/`
- `images/`
- `screenshots/`
- `exports/`
- `notebooks/`
- `dist/`
- `build/`
- `coverage/`
- `node_modules/`
- `.venv/`

Then add them to `.graphifyignore`.

### Option C: Iterate until extraction is clean

1. create a first `.graphifyignore`
2. run:

```bash
nix run ~/nix-config#graphify-extract -- .
```

3. look at the summary
4. if docs/images/papers are still non-zero, expand the ignore file
5. repeat until all three are zero

---

## Examples

### Example: Python / Node mixed project

```gitignore
*.md
*.txt
*.pdf
*.png
*.jpg
*.jpeg
*.svg
*.yaml
*.yml

graphify-out/
.venv/
venv/
node_modules/
dist/
build/
coverage/
docs/
```

### Example: Nix repository

```gitignore
*.md
*.txt
*.pdf
*.png
*.jpg
*.jpeg
*.svg
*.yaml
*.yml

graphify-out/
result/
.venv/
.graphify-src/
docs/
draft/
```

### Example: Rust project

```gitignore
*.md
*.txt
*.pdf
*.png
*.jpg
*.jpeg
*.svg
*.yaml
*.yml

graphify-out/
target/
docs/
```

---

## Using Graphify with the installed Skill

Once your system config is applied, the `graphify` skill can be used by supported coding agents.

Good prompts include:

- `Use graphify to map this project and explain the architecture`
- `Use graphify to show what depends on mcp`
- `Use graphify to find the path from A to B`

Expected workflow:

1. the agent selects the `graphify` skill
2. it finds your `nix-config` flake path
3. it builds or updates `graphify-out/graph.json`
4. it queries the graph first
5. only then does it fall back to direct file reads if needed

---

## Using Graphify with MCP

Your configuration already provides a `graphify` MCP server.

The wrapper behaves like this:

1. use `GRAPHIFY_GRAPH_PATH` if it is set
2. otherwise search upward from the current directory for `graphify-out/graph.json`

Use MCP when you want structured graph navigation such as:

- `query_graph`
- `get_node`
- `get_neighbors`
- `shortest_path`

---

## Recommended working loop

```bash
cd /path/to/project
nix run ~/nix-config#graphify-extract -- .
nix run ~/nix-config#graphify-query -- "explain the architecture" --graph ./graphify-out/graph.json
# edit code
nix run ~/nix-config#graphify-update -- .
```

---

## Troubleshooting

### `graphify-extract: command not found`

Your shell aliases are not loaded yet.

Use the explicit flake command instead:

```bash
nix run ~/nix-config#graphify-extract -- .
```

Or apply your config and open a new shell.

### `no LLM API key found`

Your corpus still contains docs, papers, or images.

Fix `.graphifyignore` and run again.

### `graphify MCP: graph.json not found`

Build the graph first:

```bash
nix run ~/nix-config#graphify-extract -- .
```

Or set:

```bash
export GRAPHIFY_GRAPH_PATH=/abs/path/to/graphify-out/graph.json
```

### Extraction works on a subdirectory but not the repo root

Your repo root still contains files that Graphify classifies as documents. Expand `.graphifyignore` until extraction reports zero docs, papers, and images.

---

## Quick checklist

Before using Graphify offline, verify:

- `.graphifyignore` exists
- docs/images/office/media are excluded
- generated directories are excluded
- `graphify extract` reports `0 docs, 0 papers, 0 images`
- `graphify-out/graph.json` exists

---

## One-line success condition

If this works:

```bash
nix run ~/nix-config#graphify-extract -- .
```

and the output says:

```text
found N code, 0 docs, 0 papers, 0 images
```

then your project is ready for offline Graphify usage.
