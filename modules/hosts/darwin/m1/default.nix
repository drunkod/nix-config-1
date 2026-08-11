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
    ssh
    kitty
    graphify
  ];

  aiFullImports = aiCoreImports ++ [
    config.flake.modules.homeManager.repo-harness
    config.flake.modules.homeManager.repo-harness-mcp
    config.flake.modules.homeManager.repo-harness-mcp-quick
    # Keep the named-tunnel module available as an opt-in stable-domain path.
    config.flake.modules.homeManager.cloudflared-mcp-tunnel
    config.flake.modules.homeManager.codex
    config.flake.modules.homeManager."pi-coding-agent"
    config.flake.modules.homeManager.jules
    config.flake.modules.homeManager."qoder-cli"
    config.flake.modules.homeManager.proxypilot-t3chat
  ];

  nixMaintenanceM1Mini = {
    launchd.daemons.nix-gc-local = {
      command = ''
        /usr/bin/caffeinate -s /usr/bin/nice -n 20 \
          /nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 14d
      '';
      serviceConfig = {
        RunAtLoad = false;
        StartCalendarInterval = [
          {
            Weekday = 7;
            Hour = 3;
            Minute = 15;
          }
        ];
        StandardOutPath = "/var/log/nix-gc-local.log";
        StandardErrorPath = "/var/log/nix-gc-local.err.log";
        ProcessType = "Background";
        LowPriorityIO = true;
      };
    };

    launchd.daemons.nix-optimise-local = {
      command = ''
        /usr/bin/caffeinate -s /usr/bin/nice -n 20 \
          /nix/var/nix/profiles/default/bin/nix-store --optimise
      '';
      serviceConfig = {
        RunAtLoad = false;
        StartCalendarInterval = [
          {
            Weekday = 7;
            Hour = 4;
            Minute = 15;
          }
        ];
        StandardOutPath = "/var/log/nix-optimise-local.log";
        StandardErrorPath = "/var/log/nix-optimise-local.err.log";
        ProcessType = "Background";
        LowPriorityIO = true;
      };
    };
  };
in
{
  flake.modules.darwin.nixMaintenanceM1Mini = nixMaintenanceM1Mini;

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

      nixMaintenanceM1Mini
      aerospace
      homebrewM1Minimal
      sleepless
      kitty
    ];
  };

  flake.modules.darwin.m1-min = {
    host = minimalHost;
    home-manager.users.${minimalHost.user.name} =
      { config, ... }:
      {
        imports = aiFullImports;
        services = {
          sops.enable = true;

          repo-harness-mcp = {
            enable = true;
            repoPath = "${config.home.homeDirectory}/nix-config";
            profile = "coding";
            accessMode = "read_write";
            host = "127.0.0.1";
            port = 8765;
            serverName = "repo-harness-coding";
            publicEndpoint = null;
            autoStart = true;
          };

          # Default public path: an ephemeral *.trycloudflare.com Quick Tunnel.
          # No Cloudflare account, custom domain, tunnel UUID, or DNS setup is
          # required. Use rh-mcp-quick-restart to create/replace the endpoint.
          repo-harness-mcp-quick = {
            enable = true;
            waitSeconds = 45;
            publishGraceSeconds = 20;
            publicReadySeconds = 120;
            retryIntervalSeconds = 5;
            probeCount = 5;
          };

          # Optional stable-domain path. The module remains imported so it can
          # be enabled deliberately after Cloudflare login/tunnel/DNS setup,
          # but m1-min does not start a named tunnel by default.
          cloudflared-mcp-tunnel.enable = false;
        };
      };
  };
}
