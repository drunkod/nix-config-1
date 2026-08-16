# t3.chat `m1-min` example snapshot

This directory is a version-sensitive reference snapshot for the
[current narrative guide](../../macos/t3chat-launch.md). The `.nix` files are not
the canonical configuration and are intentionally unchanged by documentation
maintenance.

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

## Use the snapshot

Compare individual sections with the current repository and port only reviewed
changes. Do not overwrite the current flake or host modules wholesale.

```bash
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
