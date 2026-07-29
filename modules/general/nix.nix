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

  flake.modules.darwin.base = {
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
  };

  flake.modules.homeManager.disable = { pkgs, ... }: { };
}
