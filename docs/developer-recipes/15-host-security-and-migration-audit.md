# Recipe 15: audit host security and legacy integration

Use this after a Repo Harness upgrade or when editor/hook behavior differs between
machines. These checks do not modify project source. Shared rules:
[`Repo Harness safety`](../repo-harness/safety.md).

## 1. Inspect runtime state

```bash
repo-harness --version
repo-harness install --state --json
repo-harness setup check --json
repo-harness doctor --json
```

Structured warnings or blocked checks may produce a nonzero exit. Read the JSON
findings instead of treating nonzero as missing output.

## 2. Scan hook and editor configuration

```bash
repo-harness security scan --json
```

Use `--strict` in CI or a deliberate gate when high-risk or failed findings must
produce a nonzero result.

## 3. Preview legacy hook migration

```bash
repo-harness migrate --json
```

The command is dry-run by default. Review every planned removal and global
adapter change before using `repo-harness migrate --apply`.

## 4. Check retired MCP scope

```bash
repo-harness mcp doctor --repo "$PWD" --json
repo-harness mcp migrate-scope --help
```

`mcp migrate-scope` rotates credentials while moving retired repo-scope state to
user-level storage. Treat it as a separate mutation, not a diagnostic command.

## 5. Compare bundled guidance

```bash
repo-harness docs list
repo-harness docs show global-working-rules
repo-harness docs show hook-operations
```

Port only reviewed host changes into the Nix configuration. Do not edit generated
host files as a substitute for their declarative source.
