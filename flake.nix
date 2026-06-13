{
  description = "Flake of Matthias Benaets";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    llm-agents.url = "github:numtide/llm-agents.nix";
    mcp-servers-nix.url = "github:natsukium/mcp-servers-nix";
    mcp-servers-nix.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    stylix.url = "github:nix-community/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";

    noctalia.url = "github:noctalia-dev/noctalia-shell";
    noctalia.inputs.nixpkgs.follows = "nixpkgs";

    graphify-vhdl-fresh.url = "path:/Users/test/Documents/work/claude-cowork/graphify-vhdl-fresh";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [ (inputs.import-tree ./modules) ];

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              nvidia.acceptLicense = true;
            };
            overlays = [
              inputs.nur.overlays.default
              inputs.llm-agents.overlays.shared-nixpkgs
              (final: prev: {
                stable = import inputs.nixpkgs-stable {
                  system = prev.system;
                  config.allowUnfree = true;
                };
                master = import inputs.nixpkgs-master {
                  system = prev.system;
                  config.allowUnfree = true;
                };
              })
            ];
          };

          apps = {
            graphify-extract = inputs.graphify-vhdl-fresh.apps.${system}.extract;
            graphify-update = inputs.graphify-vhdl-fresh.apps.${system}.update;
            graphify-query = inputs.graphify-vhdl-fresh.apps.${system}.query;
            graphify-mcp = inputs.graphify-vhdl-fresh.apps.${system}.mcp;
            graphify-test = inputs.graphify-vhdl-fresh.apps.${system}.test;
            graphify-skill = inputs.graphify-vhdl-fresh.apps.${system}.skill;
          };

          devShells = (import ./shells {
            inherit
              config
              inputs
              pkgs
              system
              ;
          }) // {
            graphify = inputs.graphify-vhdl-fresh.devShells.${system}.default;
          };
        };
    };
}
