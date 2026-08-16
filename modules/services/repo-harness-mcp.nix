{
  flake.modules.homeManager.repo-harness-mcp =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        escapeShellArg
        hasPrefix
        hasSuffix
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.services.repo-harness-mcp;
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      isLinux = pkgs.stdenv.hostPlatform.isLinux;
      profileBin = "${config.home.profileDirectory}/bin/repo-harness";
      defaultEndpoint = if cfg.publicEndpoint == null then "" else cfg.publicEndpoint;
      serviceLabel = "org.nix-community.home.repo-harness-mcp";
      urlHost = if cfg.host == "::1" then "[::1]" else cfg.host;
      isOutsideNixStore = path: path != "/nix/store" && !hasPrefix "/nix/store/" path;
      userConfigFile = "${config.home.homeDirectory}/.repo-harness/mcp.local.json";

      server = pkgs.writeShellApplication {
        name = "repo-harness-mcp-server";
        runtimeInputs = with pkgs; [
          bash
          coreutils
          git
          jq
        ];
        text = ''
          set -euo pipefail

          repo=${escapeShellArg (if cfg.repoPath == null then "" else cfg.repoPath)}
          config_file=${escapeShellArg userConfigFile}
          cli=${escapeShellArg profileBin}

          if [ -z "$repo" ] || [ ! -d "$repo" ]; then
            echo "repo-harness MCP: configured repository is unavailable: $repo" >&2
            exit 0
          fi

          if [ ! -x "$cli" ]; then
            echo "repo-harness MCP: launcher is unavailable; run rh-bootstrap after rebuilding" >&2
            exit 0
          fi

          if [ ! -f "$config_file" ]; then
            echo "repo-harness MCP: user-scope config is absent; run rh-mcp-bootstrap" >&2
            exit 0
          fi

          if ! jq -e '.scope == "user" and .profile == "coding" and .coding.enabled == true' \
            "$config_file" >/dev/null
          then
            echo "repo-harness MCP: local config is not an enabled coding profile" >&2
            exit 0
          fi

          exec "$cli" mcp serve \
            --repo "$repo" \
            --transport http \
            --host ${escapeShellArg cfg.host} \
            --port ${toString cfg.port} \
            --profile ${escapeShellArg cfg.profile} \
            --auth oauth
        '';
      };

      bootstrap = pkgs.writeShellApplication {
        name = "repo-harness-mcp-bootstrap";
        runtimeInputs = with pkgs; [
          bash
          coreutils
          git
          jq
        ];
        text = ''
          set -euo pipefail

          repo=${escapeShellArg (if cfg.repoPath == null then "" else cfg.repoPath)}
          endpoint=${escapeShellArg defaultEndpoint}
          dry_run=0

          while [ "$#" -gt 0 ]; do
            case "$1" in
              --repo)
                [ "$#" -ge 2 ] || { echo "--repo requires a value" >&2; exit 2; }
                repo="$2"
                shift 2
                ;;
              --endpoint)
                [ "$#" -ge 2 ] || { echo "--endpoint requires a value" >&2; exit 2; }
                endpoint="$2"
                shift 2
                ;;
              --dry-run)
                dry_run=1
                shift
                ;;
              -h|--help)
                echo "usage: rh-mcp-bootstrap [--repo PATH] [--endpoint https://HOST/mcp] [--dry-run]"
                exit 0
                ;;
              *)
                echo "unknown argument: $1" >&2
                exit 2
                ;;
            esac
          done

          [ -d "$repo" ] || {
            echo "repository does not exist: $repo" >&2
            exit 1
          }

          case "$endpoint" in
            https://*/mcp) ;;
            *)
              echo "endpoint must be a public HTTPS URL ending in /mcp" >&2
              exit 1
              ;;
          esac

          cli=${escapeShellArg profileBin}
          [ -x "$cli" ] || {
            echo "repo-harness launcher is unavailable; run rh-bootstrap" >&2
            exit 127
          }

          cmd=(
            "$cli" mcp setup chatgpt
            --repo "$repo"
            --profile ${escapeShellArg cfg.profile}
            --grant-read-write "$repo"
            --host ${escapeShellArg cfg.host}
            --port ${toString cfg.port}
            --server-name ${escapeShellArg cfg.serverName}
            --endpoint "$endpoint"
          )

          if [ "$dry_run" -eq 1 ]; then
            printf 'dry-run:'
            printf ' %q' "''${cmd[@]}"
            printf '\n'
            exit 0
          fi

          "''${cmd[@]}"

          config_file=${escapeShellArg userConfigFile}
          jq -e '
            .scope == "user"
            and .profile == "coding"
            and .coding.enabled == true
            and (.chatgpt.endpoint | endswith("/mcp"))
          ' "$config_file" >/dev/null

          echo "repo-harness coding profile configured."
          echo "The OAuth passphrase remains local in ~/.repo-harness/mcp.oauth.json."
          echo "Restart the service with: rh-mcp-restart"
        '';
      };

      health = pkgs.writeShellApplication {
        name = "repo-harness-mcp-health";
        runtimeInputs = with pkgs; [ curl ];
        text = ''
          set -euo pipefail
          curl --fail --silent --show-error --max-time 5 \
            http://${urlHost}:${toString cfg.port}/health
          printf '\n'
          curl --fail --silent --show-error --max-time 5 \
            http://${urlHost}:${toString cfg.port}/.well-known/oauth-protected-resource/mcp \
            >/dev/null
          echo "repo-harness MCP health and OAuth discovery passed"
        '';
      };

      doctor = pkgs.writeShellApplication {
        name = "repo-harness-mcp-doctor";
        runtimeInputs = with pkgs; [ jq ];
        text = ''
          set -euo pipefail
          repo=${escapeShellArg (if cfg.repoPath == null then "" else cfg.repoPath)}
          cli=${escapeShellArg profileBin}
          exec "$cli" mcp doctor --repo "$repo" --live --json "$@"
        '';
      };

      restart = pkgs.writeShellApplication {
        name = "repo-harness-mcp-restart";
        runtimeInputs = [ pkgs.coreutils ] ++ lib.optionals isLinux [ pkgs.systemd ];
        text = ''
          set -euo pipefail
          case "$(uname -s)" in
            Darwin)
              exec /bin/launchctl kickstart -k "gui/$UID/${serviceLabel}"
              ;;
            Linux)
              exec systemctl --user restart repo-harness-mcp.service
              ;;
            *)
              echo "unsupported operating system" >&2
              exit 1
              ;;
          esac
        '';
      };
    in
    {
      options.services.repo-harness-mcp = {
        enable = mkEnableOption "repo-harness MCP coding service";

        repoPath = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Absolute path of the single explicitly granted repository.";
        };

        profile = mkOption {
          type = types.enum [ "coding" ];
          default = "coding";
          description = "Explicit MCP profile. This module intentionally supports only coding.";
        };

        accessMode = mkOption {
          type = types.nullOr (types.enum [ "read_write" ]);
          default = null;
          description = "Explicit read-write grant mode required before enabling coding.";
        };

        host = mkOption {
          type = types.enum [
            "127.0.0.1"
            "localhost"
            "::1"
          ];
          default = "127.0.0.1";
          description = "Loopback address for the local MCP server.";
        };

        port = mkOption {
          type = types.port;
          default = 8765;
          description = "Local MCP HTTP port.";
        };

        serverName = mkOption {
          type = types.strMatching "[A-Za-z0-9][A-Za-z0-9._-]*";
          default = "repo-harness-coding";
          description = "ChatGPT developer-mode app/server name.";
        };

        publicEndpoint = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "https://mcp.example.com/mcp";
          description = ''
            Optional stable public endpoint. Keep it null in tracked host config
            when the real hostname must remain local, then pass --endpoint to
            rh-mcp-bootstrap.
          '';
        };

        autoStart = mkOption {
          type = types.bool;
          default = true;
          description = "Start the user service at login after local bootstrap state exists.";
        };

        logDirectory = mkOption {
          type = types.str;
          default = "${config.home.homeDirectory}/.local/state/repo-harness-mcp";
          description = "Runtime log directory outside the Nix store.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.repoPath != null && hasPrefix "/" cfg.repoPath;
            message = "services.repo-harness-mcp.repoPath must be an explicit absolute path.";
          }
          {
            assertion = cfg.profile == "coding";
            message = "services.repo-harness-mcp.profile must be explicitly set to coding.";
          }
          {
            assertion = cfg.accessMode == "read_write";
            message = "services.repo-harness-mcp.accessMode must be explicitly set to read_write.";
          }
          {
            assertion = cfg.publicEndpoint == null || (
              hasPrefix "https://" cfg.publicEndpoint && hasSuffix "/mcp" cfg.publicEndpoint
            );
            message = "services.repo-harness-mcp.publicEndpoint must be HTTPS and end in /mcp.";
          }
          {
            assertion = hasPrefix "/" cfg.logDirectory;
            message = "services.repo-harness-mcp.logDirectory must be an absolute path.";
          }
          {
            assertion = isOutsideNixStore cfg.logDirectory;
            message = "repo-harness MCP logs must not be written into the Nix store.";
          }
        ];

        home.packages = [
          bootstrap
          doctor
          health
          restart
          server
        ];

        home.activation.repoHarnessMcpRuntimeDirectories =
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run mkdir -p ${escapeShellArg cfg.logDirectory}
            run chmod 700 ${escapeShellArg cfg.logDirectory}
          '';

        launchd.agents.repo-harness-mcp = mkIf isDarwin {
          enable = true;
          domain = "gui";
          config = {
            Label = serviceLabel;
            ProgramArguments = [ "${server}/bin/repo-harness-mcp-server" ];
            WorkingDirectory = config.home.homeDirectory;
            RunAtLoad = cfg.autoStart;
            KeepAlive = {
              SuccessfulExit = false;
            };
            ThrottleInterval = 10;
            ProcessType = "Background";
            StandardOutPath = "${cfg.logDirectory}/stdout.log";
            StandardErrorPath = "${cfg.logDirectory}/stderr.log";
          };
        };

        systemd.user.services.repo-harness-mcp = mkIf isLinux {
          Unit = {
            Description = "repo-harness MCP coding service";
            After = [ "network.target" ];
          };
          Service = {
            ExecStart = "${server}/bin/repo-harness-mcp-server";
            Restart = "on-failure";
            RestartSec = 10;
            WorkingDirectory = config.home.homeDirectory;
          };
          Install.WantedBy = lib.optional cfg.autoStart "default.target";
        };

        home.shellAliases = {
          rh-mcp-bootstrap = "repo-harness-mcp-bootstrap";
          rh-mcp-doctor = "repo-harness-mcp-doctor";
          rh-mcp-health = "repo-harness-mcp-health";
          rh-mcp-restart = "repo-harness-mcp-restart";
        };
      };
    };
}
