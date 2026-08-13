# Recipe 1: build a reusable ChatGPT context packet

Use this when you want one compact package containing a repository overview plus
focused architectural evidence.

## 1. Create an ignored packet directory

```bash
cd /absolute/path/to/repository
mkdir -p .ai/context-packets/task-name
```

Ensure `.ai/context-packets/` is excluded by `.gitignore` and `.ignore`; see the
shared [`safety rules`](../repo-harness/safety.md).

## 2. Create the repository digest locally

The `m1-min` profile installs `pkgs.gitingest`. Digest the current checkout
without sending it to `gitingest.com`:

```bash
gitingest . \
  --output .ai/context-packets/task-name/gitingest.md \
  --exclude-pattern '.ai/*' \
  --exclude-pattern '.codegraph/*' \
  --exclude-pattern 'graphify-out/*' \
  --exclude-pattern '_ops/*' \
  --exclude-pattern '_ref/*'
```

Gitingest respects `.gitignore` and `.gitingestignore`. Add project-specific
generated and vendor paths there or as explicit exclusions.

If the configured package is unavailable before rebuilding, test it temporarily:

```bash
nix run nixpkgs#gitingest -- . \
  --output .ai/context-packets/task-name/gitingest.md
```

For a remote repository, `gitingest https://github.com/OWNER/REPOSITORY` is also
supported. External-processing guidance is in the shared safety guide.

For the smallest packet, skip the full digest and save only filenames plus
reviewed source excerpts:

```bash
git ls-files > .ai/context-packets/task-name/files.txt
```

## 3. Add CodeGraph focus

Run the shared [index preflight](README.md#shared-index-preflight), then:

```bash
codegraph explore \
  "Trace <feature> from entry point to storage and list the most relevant files" \
  --path "$PWD" \
  --max-files 10 \
  > .ai/context-packets/task-name/codegraph.md
```

CodeGraph output already contains focused source and call paths. Avoid duplicating
the same files again in the digest when attachment size matters.

## 4. Optionally add Graphify structure

```bash
graphify-query \
  "<feature> entry points callers dependencies paths" \
  --graph "$PWD/graphify-out/graph.json" \
  --budget 2000 \
  > .ai/context-packets/task-name/graphify.md
```

Use one explicit graph from this repository only.

## 5. Add the task brief

Create `.ai/context-packets/task-name/brief.md`:

```markdown
# Task

## Goal

## Current behavior

## Expected behavior

## Constraints

## Questions

## Allowed paths

## Forbidden paths
```

## 6. Review before sharing

```bash
find .ai/context-packets/task-name -type f -print
wc -c .ai/context-packets/task-name/*
```

Open the files locally and remove irrelevant source and stale output.

## 7. Send to ChatGPT

### Normal ChatGPT chat

Attach the reviewed files manually and ask ChatGPT to cite which packet file
supports each conclusion.

### Browser Engine

Browser Engine only accepts allowed repo-relative files. `.ai/context-packets/`
may not be in its allowed attachment surface. Prefer reviewed copies under an
allowed path such as `docs/researches/`, or use existing `README.md`, `docs/**`,
`plans/**`, and `tasks/**` files explicitly:

```bash
repo-harness chatgpt browser-consult \
  --repo . \
  --provider oracle \
  --dry-run \
  --prompt "Analyze the attached context and produce a bounded plan. Do not implement." \
  --file docs/researches/task-name-context.md \
  --write-output .ai/harness/handoff/chatgpt/task-name-plan.md
```

### Coding MCP

Do not attach the digest to the connector automatically. Open the exact managed
workspace and let ChatGPT use repository tools plus CodeGraph. Provide the brief
and only the reviewed conclusions from the packet.

## Cleanup

```bash
rm -r -- .ai/context-packets/task-name
```

Confirm the task path before removal.
