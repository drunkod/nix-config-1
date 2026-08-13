# Recipe 2: understand unfamiliar code quickly

Use this before changing a feature you did not write. Shared rules:
[`Repo Harness safety`](../repo-harness/safety.md).

## 1. Refresh the indexes

```bash
cd /absolute/path/to/repository
```

Run the shared [index preflight](README.md#shared-index-preflight).

## 2. Ask three focused CodeGraph questions

```bash
codegraph explore \
  "What are the entry points for <feature>, and what calls them?" \
  --path "$PWD" --max-files 8

codegraph explore \
  "Trace <feature> from input through validation to persistence/output" \
  --path "$PWD" --max-files 10

codegraph explore \
  "What tests cover <feature>, and what would be affected by changing it?" \
  --path "$PWD" --max-files 8
```

Do not start with “explain the whole repository.” Name a feature, route, command,
class, function, or file.

## 3. Use Graphify for relationship questions

```bash
graphify-query \
  "<feature> callers dependencies tests" \
  --graph "$PWD/graphify-out/graph.json" \
  --budget 2000
```

Use Graphify paths and dependency traversal when CodeGraph's source-focused
answer is not enough. Do not query both tools automatically for every question.

## 4. Create a short map

Save only conclusions, not huge raw dumps:

```markdown
# Feature map

- Entry point:
- Main flow:
- State/storage:
- External boundaries:
- Tests:
- Risky dependencies:
- Files likely relevant:
- Unknowns to verify:
```

## 5. Ask ChatGPT to challenge the map

Attach the map in normal ChatGPT, or use Browser Engine with a reviewed file
under `docs/**`:

```text
Review this feature map. Identify unsupported assumptions, missing failure paths,
and the minimum source files needed before implementation. Do not write code.
```

## 6. Before editing

Verify important claims against current source. In Coding MCP, open a managed
workspace from an exact SHA and run `codegraph init .` before the first patch.
