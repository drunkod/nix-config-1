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
    # Clear the extra Determinate/FlakeHub substituters so only cache.nixos.org is used.
    system.activationScripts.nixCustomConf.text = ''
      cat > /etc/nix/nix.custom.conf <<'NIXCUSTOM'
      extra-substituters =
      extra-trusted-substituters =
      extra-nix-path =
      NIXCUSTOM
    '';
  };

  flake.modules.homeManager.disable = { pkgs, ... }: { };
}
