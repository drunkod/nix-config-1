# MacBook M1 Setup

This repository has two Darwin hosts for Apple Silicon Macs:

- `m1-min`: minimal daily-driver profile with the adopted AI terminal tools.
- `m1`: full upstream profile with the larger Homebrew app set.

## First Switch

From this repository:

```bash
nix build .#darwinConfigurations.m1-min.system \
  --extra-experimental-features 'nix-command flakes'
./result/sw/bin/darwin-rebuild switch --flake .#m1-min
```

## Later Switches

After `darwin-rebuild` is available on `PATH`:

```bash
darwin-rebuild switch --flake .#m1-min
```

## Current Local Assumptions

- macOS user: `test`
- target system: `aarch64-darwin`
- minimal host output: `darwinConfigurations.m1-min`
- full host output: `darwinConfigurations.m1`

The copied `modules/home/programs/terminal/tools/*` modules have been adapted
as Home Manager modules and are imported by `m1-min`.
