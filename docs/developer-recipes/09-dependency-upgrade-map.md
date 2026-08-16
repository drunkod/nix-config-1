# Recipe 9: map a dependency upgrade before changing versions

Use this before upgrading a library, runtime, framework, or API client. Run the
shared [index preflight](README.md#shared-index-preflight). Shared rules:
[`Repo Harness safety`](../repo-harness/safety.md).

## 1. Find every integration point

```bash
mkdir -p .ai/context-packets/dependency-upgrade

codegraph explore \
  "Where is <dependency> imported, wrapped, configured, mocked, and tested? Include compatibility adapters and generated clients." \
  --path "$PWD" \
  --max-files 15 \
  > .ai/context-packets/dependency-upgrade/codegraph-usage.md
```

## 2. Find architectural concentration

```bash
nix shell nixpkgs#coreutils --command \
  graphify-query \
  "<dependency> wrappers consumers dependency paths tests configuration" \
  --graph "$PWD/graphify-out/graph.json" \
  --budget 2200 \
  > .ai/context-packets/dependency-upgrade/graphify-map.md
```

This reveals whether the dependency is isolated behind one adapter or spread
across many callers and dependency paths.

## 3. Build a focused compatibility digest

Create `upgrade-files.txt` containing the reviewed manifest, lock file, wrappers,
callers, and tests identified above. Then:

```bash
nix shell nixpkgs#coreutils --command \
  "$HOME/nix-config/scripts/gitingest-selected.sh" \
  "$PWD" \
  .ai/context-packets/dependency-upgrade/upgrade-files.txt \
  .ai/context-packets/dependency-upgrade/compatibility-source.md
```

## 4. Resolve upgrade risk

```bash
repo-harness state resolve \
  --target-path path/to/manifest \
  --target-path path/to/lock-file \
  --operation modify \
  --json
```

## 5. Ask ChatGPT for an upgrade plan

```text
Compare the current dependency integration with the target release notes I
attached. Identify incompatible APIs, migration order, tests, rollback, and
whether an adapter can keep the change bounded. Do not edit versions yet.
```

After upgrading, rerun CodeGraph and regenerate the focused digest to produce a
before/after review packet.
