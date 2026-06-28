{
  inputs,
  ...
}:

{
  flake.modules.nixos.base = {
    nix = {
      settings = {
        auto-optimise-store = true;
      };
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 2d";
      };
      registry.nixpkgs.flake = inputs.nixpkgs;
      extraOptions = ''
        experimental-features = nix-command flakes
        keep-outputs          = true
        keep-derivations      = true
      '';
    };
  };

  flake.modules.darwin.base =
    { pkgs, ... }:
    let
      gcScript = pkgs.writeShellScript "nix-gc-weekly" ''
        set -eu
        exec /usr/bin/caffeinate -s /usr/bin/nice -n 20 \
          ${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 7d
      '';

      optimiseScript = pkgs.writeShellScript "nix-store-optimise-weekly" ''
        set -eu
        exec /usr/bin/caffeinate -s /usr/bin/nice -n 20 \
          ${pkgs.nix}/bin/nix-store --optimise
      '';
    in
    {
      nix.enable = false;

      # Determinate Systems manages /etc/nix/nix.conf but includes nix.custom.conf for overrides.
      # Keep nix-darwin from taking over Nix itself, but retain local cache and free-space policy.
      system.activationScripts.nixCustomConf.text = ''
        cat > /etc/nix/nix.custom.conf <<'NIXCUSTOM'
        extra-substituters =
        extra-trusted-substituters =
        extra-nix-path =
        experimental-features = nix-command flakes
        keep-outputs = true
        keep-derivations = true
        connect-timeout = 10
        stalled-download-timeout = 300
        fallback = true
        min-free = 1073741824
        max-free = 10737418240
        NIXCUSTOM
      '';

      launchd.daemons.nix-gc-local = {
        command = toString gcScript;
        serviceConfig = {
          StartCalendarInterval = [
            {
              Weekday = 0;
              Hour = 3;
              Minute = 15;
            }
          ];
          StandardOutPath = "/var/log/nix-gc.log";
          StandardErrorPath = "/var/log/nix-gc.err.log";
          ProcessType = "Background";
          LowPriorityIO = true;
        };
      };

      launchd.daemons.nix-optimise-local = {
        command = toString optimiseScript;
        serviceConfig = {
          StartCalendarInterval = [
            {
              Weekday = 0;
              Hour = 4;
              Minute = 15;
            }
          ];
          StandardOutPath = "/var/log/nix-optimise.log";
          StandardErrorPath = "/var/log/nix-optimise.err.log";
          ProcessType = "Background";
          LowPriorityIO = true;
        };
      };
    };

  flake.modules.homeManager.disable = { pkgs, ... }: { };
}
