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
  aiCoreImports = with config.flake.modules.homeManager; [
    inputs.sops-nix.homeManagerModules.sops
    sops
    config.flake.modules.homeManager."claude-code"
    config.flake.modules.homeManager.zed
    mcp
    zsh
    kitty
    graphify
  ];

  aiFullImports = aiCoreImports ++ [
    config.flake.modules.homeManager.codex
    config.flake.modules.homeManager."pi-coding-agent"
  ];
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
      imports = aiCoreImports;
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
      imports = aiFullImports;
      services.sops.enable = true;
    };
  };
}
