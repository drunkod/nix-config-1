# Sleepless on macOS with nix-darwin

[macOS integrations](README.md) · [Documentation index](../README.md)

This repository provides a reusable `sleepless` Darwin module that installs the open-source [Sleepless](https://github.com/Aboudjem/Sleepless) menu-bar app and grants only the two privileged `pmset` commands it needs.

Sleepless keeps a MacBook running with the lid closed. The current upstream Homebrew cask requires macOS Tahoe 26 or newer.

## What the module configures

The module lives at `modules/programs/sleepless.nix` and does two things:

1. Installs the trusted third-party cask `aboudjem/tap/sleepless`.
2. Adds a narrow sudoers rule for exactly these commands:

```text
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -a disablesleep 1
```

Because nix-darwin manages the sudoers rule, do not run Sleepless's bundled `grant.sh` script after activation.

## Enable Sleepless on a host

Modules under `modules/` are discovered automatically by `import-tree`. Add `sleepless` to the Darwin host's module list.

For `m1-min`, the configuration is:

```nix
flake.darwinConfigurations.m1-min = inputs.darwin.lib.darwinSystem {
  system = minimalHost.system;
  specialArgs = { inherit inputs; };
  modules = with config.flake.modules.darwin; [
    base
    m1-min

    nixMaintenanceM1Mini
    aerospace
    homebrewM1Minimal
    sleepless
    kitty
  ];
};
```

Use the same pattern for another Darwin host: add `sleepless` to that host's `modules` list. The host must expose `config.host.user.name`, because the module uses it when creating the restricted sudoers entry.

## Evaluate before activation

From the repository root, verify that the `m1-min` configuration evaluates:

```bash
nix eval \
  .#darwinConfigurations.m1-min.config.system.build.toplevel.drvPath \
  --show-trace
```

Build the complete system closure without activating it:

```bash
nix build .#darwinConfigurations.m1-min.system
```

## Activate

```bash
sudo darwin-rebuild switch --flake .#m1-min
```

The activation should install `/Applications/Sleepless.app` and write the restricted sudoers configuration through nix-darwin.

## Verify the installation

Check that Homebrew and macOS can see the application:

```bash
brew list --cask | grep '^sleepless$'
test -d /Applications/Sleepless.app && echo 'Sleepless.app installed'
```

Validate the complete sudoers configuration:

```bash
sudo visudo -c
```

## Test the privileged sleep toggle

The following test enables the kernel sleep-disabled flag, verifies it, and always restores normal sleep when the shell exits:

```bash
set -e
trap 'sudo -n /usr/bin/pmset -a disablesleep 0' EXIT

sudo -n /usr/bin/pmset -a disablesleep 1
pmset -g | grep SleepDisabled
```

Expected output includes:

```text
 SleepDisabled          1
```

After the command exits, confirm that normal sleep was restored:

```bash
pmset -g | grep SleepDisabled
```

Expected output includes `SleepDisabled 0`, or the setting may be absent after macOS normalises its power configuration.

## Test the application

Open Sleepless:

```bash
open -a Sleepless
```

The release is ad-hoc signed rather than Apple-notarised. On first launch, macOS may block it. Open **System Settings → Privacy & Security**, choose **Open Anyway**, then launch the app again.

1. Click the Sleepless cup icon in the menu bar.
2. Set a battery floor and, optionally, an auto-off timer.
3. Enable Sleepless.
4. Run `pmset -g | grep SleepDisabled`; it should report `1`.
5. Disable Sleepless and verify that the value returns to `0`.

For an end-to-end lid test, connect to the Mac from another device over SSH, enable Sleepless, close the lid, and confirm after a minute that the SSH session remains responsive. Keep the Mac on a hard, ventilated surface and do not leave it running closed inside a bag.

## Troubleshooting

### Homebrew rejects or skips the cask

The module marks the fully qualified third-party cask as trusted. Ensure the host is using the current nix-darwin Homebrew module and that the Mac runs macOS Tahoe 26 or newer.

### `sudo -n` asks for a password or fails

Re-run the activation, then inspect the generated rule:

```bash
sudo grep disablesleep /etc/sudoers.d/10-nix-darwin-extra-config
sudo visudo -c
```

The username in the rule must match `config.host.user.name` for the active host.

### Restore normal sleep manually

```bash
sudo /usr/bin/pmset -a disablesleep 0
pmset -g | grep SleepDisabled
```

A reboot also resets the sleep-disabled state.
