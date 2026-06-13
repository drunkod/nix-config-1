# graphify package notes

## Current status

This is a runtime MVP for Graphify (`graphifyy` on PyPI, `graphify` CLI).

Verified:

- `graphify --version`
- `graphify --help`
- offline code-only extraction on `tests/graphify-smoke`

## Known limitations

- The package currently includes only the `tree-sitter` grammar bindings available in this flake's `nixpkgs` Python package set.
- It is not yet an upstream-complete grammar set.
- Running `graphify extract .` on the repository root may require an API key if docs, images, or other semantic-extraction inputs are included in the corpus.
- Use a strict `.graphifyignore` or the dedicated `tests/graphify-smoke` fixture for offline tests.

## Repeatable smoke test

```bash
tests/graphify-smoke/run.sh
```
