# Full example files for `t3chat-macos-launch` on `m1-min`

These files are complete examples for integrating the private `pp-t3` / ProxyPilot t3.chat launcher into the `m1-min` profile.

They are intentionally stored under `docs/examples/` so you can review them before copying them into the real configuration.

## Files

| Example file | Copy to |
|---|---|
| `flake.nix` | `flake.nix` |
| `modules-hosts-darwin-m1-default.nix` | `modules/hosts/darwin/m1/default.nix` |
| `proxypilot-t3chat.nix` | `modules/programs/proxypilot-t3chat.nix` |

## Recommended source choice

Use the SSH input:

```nix
pp-t3 = {
  url = "git+ssh://git@github.com/drunkod/pp-t3.git?ref=t3go";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

This keeps `nix-config-1` declarative and avoids committing or vendoring a local clone into `draft/`.

Use a local path only when actively developing `pp-t3` at the same time:

```nix
pp-t3 = {
  url = "path:/Users/test/src/pp-t3";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

## Apply the example

From the repo root:

```bash
cp docs/examples/t3chat-macos-launch-m1-min/flake.nix flake.nix
cp docs/examples/t3chat-macos-launch-m1-min/modules-hosts-darwin-m1-default.nix modules/hosts/darwin/m1/default.nix
cp docs/examples/t3chat-macos-launch-m1-min/proxypilot-t3chat.nix modules/programs/proxypilot-t3chat.nix

nix flake lock --update-input pp-t3
nix flake check --show-trace
darwin-rebuild switch --flake .#m1-min
```

If `--update-input` is unavailable on your Nix version, use:

```bash
nix flake update pp-t3
```

## Runtime commands after rebuild

```bash
t3chat-import   # interactive browser-cookie import
t3chat-start    # start or restart the LaunchAgent
t3chat-status   # inspect launchd service state
t3chat-logs     # follow ProxyPilot stderr log
t3chat-models   # list models through local ProxyPilot
```

Use these client settings for OpenAI-compatible tools:

```text
Base URL: http://127.0.0.1:8317/v1
API key : local-dev-key
```

## Why this does not automate `t3chat-import`

The t3.chat provider uses browser cookies plus `convexSessionId`. Those values are sensitive browser-session credentials and can expire. Importing them is intentionally manual; the launch automation only starts the local ProxyPilot server after login.
