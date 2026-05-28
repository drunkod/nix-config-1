{
  config,
  inputs,
  ...
}:

let
  host = {
    name = "MacBookAirM1";
    user.name = "test";
    state = {
      darwin = 4;
      version = "22.05";
    };
    system = "aarch64-darwin";
  };

  minimalHost = host // {
    name = "MacBookAirM1Minimal";
  };
in
{
  flake.darwinConfigurations.m1 = inputs.darwin.lib.darwinSystem {
    system = host.system;
    specialArgs = { inherit inputs; };
    modules = with config.flake.modules.darwin; [
      base
      m1

      homebrewM1
      aerospace
      kitty
      nixvim
    ];
  };

  flake.modules.darwin.m1 = {
    inherit host;
    home-manager.users.${host.user.name} = {
      imports = with config.flake.modules.homeManager; [
        inputs.sops-nix.homeManagerModules.sops
        sops
        claude
        zsh
      ];
      services.sops.enable = true;
    };
  };

  flake.darwinConfigurations.m1-min = inputs.darwin.lib.darwinSystem {
    system = minimalHost.system;
    specialArgs = { inherit inputs; };
    modules = with config.flake.modules.darwin; [
      base
      m1-min

      aerospace
      homebrewM1Minimal
      kitty
    ];
  };

  flake.modules.darwin.m1-min = {
    host = minimalHost;
    home-manager.users.${minimalHost.user.name} = {
      imports = [
        inputs.sops-nix.homeManagerModules.sops
        config.flake.modules.homeManager.sops
        config.flake.modules.homeManager."claude-code"
        config.flake.modules.homeManager.codex
        config.flake.modules.homeManager."pi-coding-agent"
        config.flake.modules.homeManager.zsh
      ];
      services.sops.enable = true;
    };
  };
}
