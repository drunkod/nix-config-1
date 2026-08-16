# Recipe 4: plan a safe refactor

Use this before renaming, moving, splitting, or replacing a shared abstraction.
Shared rules: [`Repo Harness safety`](../repo-harness/safety.md).

## 1. Define the invariant

Write what must remain true:

```markdown
# Refactor brief

- Target abstraction:
- Why change it:
- Behavior that must not change:
- Public/API compatibility:
- Data migration:
- Performance constraints:
- Rollback:
```

## 2. Measure blast radius with CodeGraph

Run the shared [index preflight](README.md#shared-index-preflight), then:

```bash
codegraph explore \
  "What depends on <symbol/module>, what calls it, and which tests are affected?" \
  --path "$PWD" \
  --max-files 15
```

For changed files, use affected-test analysis when appropriate:

```bash
BASE=origin/main
git diff --name-only "$BASE"...HEAD |
codegraph affected --path "$PWD" --stdin
```

## 3. Use Graphify for architecture boundaries

```bash
nix shell nixpkgs#coreutils --command \
  graphify-query \
  "<abstraction> callers dependencies paths blast radius" \
  --graph "$PWD/graphify-out/graph.json" \
  --budget 2500
```

Look for hidden callers, long dependency paths, and modules that should not be
changed together.

## 4. Check Repo Harness architecture projection

For a standard-adopted repository with `.ai/harness/policy.json`:

```bash
repo-harness architecture-projection status --json
repo-harness architecture-projection plan \
  --changed-path path/to/proposed-file \
  --json
```

If the policy file is absent, skip this step: architecture projection is not
configured for that repository.

For configured capability-local context, also preview the affected instructions:

```bash
repo-harness capability-context request \
  --repo "$PWD" \
  --path path/to/proposed-file \
  --json
repo-harness capability-context sync \
  --repo "$PWD" \
  --path path/to/proposed-file \
  --dry-run \
  --json
```

## 5. Ask ChatGPT for staged options

Provide the refactor brief and focused graph evidence:

```text
Propose three options: minimal compatibility patch, staged migration, and full
replacement. For each list exact paths, sequencing, tests, rollback, and risks.
Do not implement.
```

## 6. Choose increments

Prefer independently verifiable steps:

1. characterization tests;
2. compatibility adapter;
3. move one caller group;
4. validate;
5. remove old path only after all callers migrate.

Create a Standard/Strict plan only when task risk requires it:

```bash
repo-harness state resolve \
  --target-path path/to/proposed-file \
  --operation modify \
  --json
```

## 7. Execute safely

Use one managed workspace per coherent branch. Initialize CodeGraph separately
inside each worktree. After each increment:

```text
targeted tests
codegraph sync .
impact query
architecture-projection check for each changed path, when configured
status + diff
```

Do not share or copy `.codegraph/` or `graphify-out/` between worktrees.
