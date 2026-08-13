# Graphify reference: add and watch

Version scope: Graphify revision `0b2bd938c4a48e91d27f0ba09b96409e0a36c78a`. Recheck `graphify --help` before use.

## Add a URL (opt-in)

`add` fetches external content into a corpus and may require network access, API keys, or format-specific extras. Use it only when the user explicitly requests non-code ingestion.

```bash
graphify add <url> --dir <project>/raw
# optional metadata:
graphify add <url> --dir <project>/raw --author "Name" --contributor "Name"
```

After a successful add, inspect what was downloaded before updating. Documents, PDFs, images, audio, and video are semantic inputs; do not process them in an offline code-only workflow.

## Watch code changes

```bash
graphify watch /absolute/path/to/project
```

Watch is a foreground process; stop it with Ctrl+C. It is intended for code refreshes. If it reports pending semantic inputs, do not enable providers automatically—ask the user, then confirm required network access, API keys, and extras.

For a one-shot code refresh, prefer:

```bash
graphify-update /absolute/path/to/project
```

`graphify-update` does **not** support `--code-only`; `update` is already the code-update path at this revision. Never invoke `graphify-out/.graphify_python`.
