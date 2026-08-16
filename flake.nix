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

    # This configuration uses Noctalia v4's programs.noctalia-shell API and
    # JSON settings. v4.7.7 is the final v4 release; v5 uses programs.noctalia.
    noctalia.url = "github:noctalia-dev/noctalia/v4.7.7";
    noctalia.inputs.nixpkgs.follows = "nixpkgs";

    graphify-src = {
      url = "github:safishamsi/graphify/v8";
      flake = false;
    };

    # Tududi's feature/nixos-module branch, pinned to the researched package
    # revision. Keep its own nixpkgs input initially instead of following our
    # unstable nixpkgs; validate the native Darwin package before deduplicating.
    tududi.url = "github:dlip/tududi/2fa53e92223773c5a5a288e9c0252bc2ea952064";

    # ProxyPilot fork with native t3.chat support.
    # Recommended for this private repo: SSH URL so Nix can authenticate via your GitHub SSH key.
    pp-t3 = {
      url = "git+ssh://git@github.com/drunkod/pp-t3.git?ref=t3go";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Local development alternative:
    # pp-t3 = {
    #   url = "path:/Users/test/src/pp-t3";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
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

          # graphify apps / packages / dev shell live in modules/programs/graphify.nix
          devShells = import ./shells {
            inherit
              config
              inputs
              pkgs
              system
              ;
          };

          checks = import ./checks/repo-harness-mcp.nix { inherit pkgs; };
        };
    };
}
