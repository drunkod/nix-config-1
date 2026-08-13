# Graphify reference: extraction contract

Version scope: Graphify revision `0b2bd938c4a48e91d27f0ba09b96409e0a36c78a`. Treat graph schema and generated artifacts as implementation details that may change; inspect the output produced by the installed revision rather than constructing intermediate JSON manually.

## Default: deterministic code-only extraction

```bash
graphify-extract /absolute/path/to/project --code-only
```

Equivalent flake app:

```bash
nix run <nix-config-flake>#graphify-extract -- \
  /absolute/path/to/project --code-only
```

The wrapper performs a fresh extraction and writes the project-local graph under:

```text
<project>/graphify-out/graph.json
```

Before extraction, use `.graphifyignore` to exclude generated/vendor trees and non-code inputs. A healthy offline run processes code locally and does not require an API key.

## Semantic extraction is opt-in

Running extraction without `--code-only` enables the AST + semantic path. Documents, papers, images, databases, and other non-code sources may require network access, provider API keys, or extras. Use that path only at the user's request, after checking `graphify --help` and the configured extras.

Do not invent extraction subagents, chunk pipelines, node-ID rules, or temporary `.graphify_*` files. Do not manually write or merge Graphify's internal extraction JSON. Never invoke `graphify-out/.graphify_python`.
