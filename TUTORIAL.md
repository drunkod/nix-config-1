# Install and Update Tutorial

This tutorial targets the minimal Apple Silicon profile in this repository:
`darwinConfigurations.m1-min`.

## Requirements

- macOS on Apple Silicon.
- Nix installed with flakes enabled.
- This repository at `/Users/test/nix-config`.
- Current macOS user: `test`.

If Nix is not installed yet, install it first:

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

Then enable flakes:

```bash
mkdir -p ~/.config/nix
printf 'experimental-features = nix-command flakes\n' >> ~/.config/nix/nix.conf
```

Restart the terminal after installing Nix.

## First Install

Build the minimal Darwin system:

```bash
cd /Users/test/nix-config
nix build .#darwinConfigurations.m1-min.system \
  --extra-experimental-features 'nix-command flakes'
```

Switch to the built system:

```bash
./result/sw/bin/darwin-rebuild switch --flake .#m1-min
```

After the first switch, `darwin-rebuild` should be available on `PATH`.

## Later Rebuilds

Use this after editing configuration files:

```bash
cd /Users/test/nix-config
darwin-rebuild switch --flake .#m1-min
```

To test evaluation before switching:

```bash
nix eval .#darwinConfigurations.m1-min.config.system.build.toplevel.drvPath \
  --raw \
  --extra-experimental-features 'nix-command flakes'
```

To preview the build plan without switching:

```bash
nix build .#darwinConfigurations.m1-min.system \
  --dry-run \
  --extra-experimental-features 'nix-command flakes'
```

## Update Inputs

Update all flake inputs:

```bash
cd /Users/test/nix-config
nix flake update --extra-experimental-features 'nix-command flakes'
```

Then rebuild:

```bash
darwin-rebuild switch --flake .#m1-min
```

Update one input only:

```bash
nix flake lock \
  --update-input nixpkgs \
  --extra-experimental-features 'nix-command flakes'
```

## Roll Back

List system generations:

```bash
darwin-rebuild --list-generations
```

Switch to the previous generation:

```bash
darwin-rebuild rollback
```

## Minimal Profile Contents

The `m1-min` profile includes:

- AeroSpace window manager.
- Kitty terminal.
- Nixvim.
- Zsh configuration.
- Codex, Claude Code, and Pi coding agent config.
- Minimal Homebrew apps: Firefox, Raycast, Visual Studio Code, and `mas`.

## AeroSpace Setup

After switching, launch AeroSpace once:

```bash
open -a AeroSpace
```

Grant Accessibility permissions when macOS prompts:

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Accessibility.
4. Enable AeroSpace.

If keybindings do not work after granting permissions, restart AeroSpace:

```bash
pkill AeroSpace
open -a AeroSpace
```

## Common Commands

Check what changed locally:

```bash
git status --short
git diff --stat
```

Format touched Nix files:

```bash
nix run nixpkgs#nixfmt --extra-experimental-features 'nix-command flakes' -- <file.nix>
```

Garbage collect old Nix store paths:

```bash
nix store gc
```

## Notes

- The full upstream profile remains available as `darwinConfigurations.m1`.
- The copied `modules/home/` tree is currently reference material and should not
  be committed as-is. This repository's import-tree will try to load support
  `.nix` files from that tree as flake modules.
- The active adopted AI modules live in `modules/programs/ai-tools.nix`.
