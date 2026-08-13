# Recipe 10: trace a contract change across layers

Use this when changing an API field, event shape, database column, config option,
or serialized type. Run the shared
[index preflight](README.md#shared-index-preflight). Shared rules:
[`Repo Harness safety`](../repo-harness/safety.md).

## 1. Trace producer to consumer

```bash
mkdir -p .ai/context-packets/contract-change

codegraph explore \
  "Trace <field/type/event> from definition and producer through validation, transport, storage, consumers, UI, and tests" \
  --path "$PWD" \
  --max-files 15 \
  > .ai/context-packets/contract-change/end-to-end-trace.md
```

## 2. Detect architectural boundaries

```bash
nix shell nixpkgs#coreutils --command \
  graphify-query \
  "<field/type/event> producers consumers serialization persistence dependency paths" \
  --graph "$PWD/graphify-out/graph.json" \
  --budget 2400 \
  > .ai/context-packets/contract-change/boundaries.md
```

Mark each boundary where old and new representations may coexist:

```text
schema -> parser -> domain type -> storage -> API -> client -> UI
```

## 3. Plan architecture projection when configured

If `.ai/harness/policy.json` exists, inspect every layer that may change:

```bash
repo-harness architecture-projection status --json
repo-harness architecture-projection plan \
  --changed-path path/to/contract-definition path/to/consumer \
  --json
```

If the policy file is absent, architecture projection is not configured; retain
the CodeGraph and Graphify evidence instead.

Preview capability-local instruction updates when configured:

```bash
repo-harness capability-context request \
  --repo "$PWD" \
  --path path/to/contract-definition \
  --json
repo-harness capability-context sync \
  --repo "$PWD" \
  --pending \
  --dry-run \
  --json
```

## 4. Package only the contract chain

Put the reviewed files from the trace into `contract-files.txt`, then generate a
focused digest:

```bash
nix shell nixpkgs#coreutils --command \
  "$HOME/nix-config/scripts/gitingest-selected.sh" \
  "$PWD" \
  .ai/context-packets/contract-change/contract-files.txt \
  .ai/context-packets/contract-change/contract-chain.md
```

## 5. Ask for migration sequencing

```text
Design a backward-compatible migration for this contract. Identify the order of
producer/consumer changes, dual-read or dual-write needs, fixtures, compatibility
tests, and the point where old support can be removed.
```

After implementation, rerun the trace. Any remaining old-field consumer becomes
a concrete follow-up item. For configured repositories, also run
`repo-harness architecture-projection check --changed-path <path> --json` for
each changed layer.
