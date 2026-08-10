{
  flake.modules.homeManager.cloudflared-mcp-tunnel =
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
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.services.cloudflared-mcp-tunnel;
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      isLinux = pkgs.stdenv.hostPlatform.isLinux;
      serviceLabel = "org.nix-community.home.cloudflared-mcp-tunnel";
      localUrlHost = if cfg.localHost == "::1" then "[::1]" else cfg.localHost;
      isOutsideNixStore = path: path != "/nix/store" && !hasPrefix "/nix/store/" path;

      runner = pkgs.writeShellApplication {
        name = "cloudflared-mcp-tunnel-run";
        runtimeInputs = with pkgs; [
          cloudflared
          coreutils
          curl
          jq
        ];
        text = ''
          set -euo pipefail

          env_file=${escapeShellArg cfg.environmentFile}
          runtime_config=${escapeShellArg cfg.runtimeConfigFile}
          tunnel_id=""
          hostname=""
          credentials_file=""

          if [ ! -f "$env_file" ]; then
            echo "cloudflared MCP: local environment file is absent; run rh-cloudflared-mcp-init" >&2
            exit 0
          fi

          while IFS='=' read -r key value; do
            case "$key" in
              ""|'#'*) continue ;;
              CLOUDFLARED_TUNNEL_ID) tunnel_id="$value" ;;
              CLOUDFLARED_HOSTNAME) hostname="$value" ;;
              CLOUDFLARED_CREDENTIALS_FILE) credentials_file="$value" ;;
              *)
                echo "cloudflared MCP: unsupported key in $env_file: $key" >&2
                exit 1
                ;;
            esac
          done <"$env_file"

          [[ "$tunnel_id" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || {
            echo "cloudflared MCP: invalid tunnel UUID" >&2
            exit 1
          }
          if ! [[ "$hostname" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ ]] \
            || [[ "$hostname" == *..* ]]
          then
            echo "cloudflared MCP: invalid hostname" >&2
            exit 1
          fi

          if [ -z "$credentials_file" ]; then
            credentials_file="$HOME/.cloudflared/$tunnel_id.json"
          fi
          case "$credentials_file" in
            /*) ;;
            *)
              echo "cloudflared MCP: credentials path must be absolute" >&2
              exit 1
              ;;
          esac
          [ -f "$credentials_file" ] || {
            echo "cloudflared MCP: credentials file is missing: $credentials_file" >&2
            exit 0
          }

          ready=0
          for _ in $(seq 1 ${toString cfg.healthWaitSeconds}); do
            if curl --fail --silent --max-time 1 \
              http://${localUrlHost}:${toString cfg.localPort}/health >/dev/null 2>&1
            then
              ready=1
              break
            fi
            sleep 1
          done
          [ "$ready" -eq 1 ] || {
            echo "cloudflared MCP: local MCP health endpoint is not ready" >&2
            exit 1
          }

          credentials_json="$(printf '%s' "$credentials_file" | jq -Rs .)"

          umask 077
          mkdir -p "$(dirname "$runtime_config")"
          tmp="$(mktemp "$runtime_config.tmp.XXXXXX")"
          trap 'rm -f "$tmp"' EXIT
          cat >"$tmp" <<YAML
tunnel: $tunnel_id
credentials-file: $credentials_json

ingress:
  - hostname: $hostname
    service: http://${localUrlHost}:${toString cfg.localPort}
  - service: http_status:404
YAML
          mv "$tmp" "$runtime_config"
          trap - EXIT
          chmod 600 "$runtime_config"

          exec ${pkgs.cloudflared}/bin/cloudflared tunnel \
            --config "$runtime_config" \
            run "$tunnel_id"
        '';
      };

      init = pkgs.writeShellApplication {
        name = "cloudflared-mcp-tunnel-init";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          set -euo pipefail

          tunnel_id=""
          hostname=""
          credentials_file=""
          dry_run=0

          while [ "$#" -gt 0 ]; do
            case "$1" in
              --tunnel-id)
                [ "$#" -ge 2 ] || { echo "--tunnel-id requires a value" >&2; exit 2; }
                tunnel_id="$2"
                shift 2
                ;;
              --hostname)
                [ "$#" -ge 2 ] || { echo "--hostname requires a value" >&2; exit 2; }
                hostname="$2"
                shift 2
                ;;
              --credentials-file)
                [ "$#" -ge 2 ] || { echo "--credentials-file requires a value" >&2; exit 2; }
                credentials_file="$2"
                shift 2
                ;;
              --dry-run)
                dry_run=1
                shift
                ;;
              -h|--help)
                echo "usage: rh-cloudflared-mcp-init --tunnel-id UUID --hostname HOST [--credentials-file PATH] [--dry-run]"
                exit 0
                ;;
              *)
                echo "unknown argument: $1" >&2
                exit 2
                ;;
            esac
          done

          [[ "$tunnel_id" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || {
            echo "invalid tunnel UUID" >&2
            exit 1
          }
          if ! [[ "$hostname" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ ]] \
            || [[ "$hostname" == *..* ]]
          then
            echo "invalid hostname" >&2
            exit 1
          fi
          if [ -z "$credentials_file" ]; then
            credentials_file="$HOME/.cloudflared/$tunnel_id.json"
          fi
          case "$credentials_file" in
            /*) ;;
            *)
              echo "credentials path must be absolute" >&2
              exit 1
              ;;
          esac

          render() {
            printf 'CLOUDFLARED_TUNNEL_ID=%s\n' "$tunnel_id"
            printf 'CLOUDFLARED_HOSTNAME=%s\n' "$hostname"
            printf 'CLOUDFLARED_CREDENTIALS_FILE=%s\n' "$credentials_file"
          }

          if [ "$dry_run" -eq 1 ]; then
            render
            exit 0
          fi

          [ -f "$credentials_file" ] || {
            echo "credentials file does not exist: $credentials_file" >&2
            exit 1
          }

          env_file=${escapeShellArg cfg.environmentFile}
          umask 077
          mkdir -p "$(dirname "$env_file")"
          tmp="$(mktemp "$env_file.tmp.XXXXXX")"
          trap 'rm -f "$tmp"' EXIT
          render >"$tmp"
          mv "$tmp" "$env_file"
          trap - EXIT
          chmod 600 "$env_file"

          echo "wrote local tunnel parameters: $env_file"
          echo "No credentials were copied into the Nix store."
          echo "Restart the service with: rh-cloudflared-mcp-restart"
        '';
      };

      restart = pkgs.writeShellApplication {
        name = "cloudflared-mcp-tunnel-restart";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          set -euo pipefail
          case "$(uname -s)" in
            Darwin)
              exec /bin/launchctl kickstart -k "gui/$UID/${serviceLabel}"
              ;;
            Linux)
              exec systemctl --user restart cloudflared-mcp-tunnel.service
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
      options.services.cloudflared-mcp-tunnel = {
        enable = mkEnableOption "Cloudflare Tunnel for repo-harness MCP";

        localHost = mkOption {
          type = types.enum [
            "127.0.0.1"
            "localhost"
            "::1"
          ];
          default = "127.0.0.1";
          description = "Loopback MCP host exposed to the tunnel.";
        };

        localPort = mkOption {
          type = types.port;
          default = 8765;
          description = "Loopback MCP port exposed to the tunnel.";
        };

        environmentFile = mkOption {
          type = types.str;
          default = "${config.home.homeDirectory}/.config/repo-harness/cloudflared-mcp.env";
          description = ''
            Local runtime file containing tunnel UUID, hostname, and credentials path.
            The file is intentionally outside Git and the Nix store.
          '';
        };

        runtimeConfigFile = mkOption {
          type = types.str;
          default = "${config.home.homeDirectory}/.config/cloudflared/repo-harness-mcp.yml";
          description = "Generated cloudflared YAML path outside the Nix store.";
        };

        autoStart = mkOption {
          type = types.bool;
          default = true;
          description = "Start the tunnel at login after local runtime parameters exist.";
        };

        healthWaitSeconds = mkOption {
          type = types.ints.between 1 300;
          default = 30;
          description = "Seconds to wait for the local MCP health endpoint.";
        };

        logDirectory = mkOption {
          type = types.str;
          default = "${config.home.homeDirectory}/.local/state/cloudflared-mcp-tunnel";
          description = "Runtime log directory outside the Nix store.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = hasPrefix "/" cfg.environmentFile;
            message = "cloudflared MCP environmentFile must be an absolute path.";
          }
          {
            assertion = isOutsideNixStore cfg.environmentFile;
            message = "cloudflared MCP environmentFile must remain outside the Nix store.";
          }
          {
            assertion = hasPrefix "/" cfg.runtimeConfigFile;
            message = "cloudflared MCP runtimeConfigFile must be an absolute path.";
          }
          {
            assertion = isOutsideNixStore cfg.runtimeConfigFile;
            message = "cloudflared MCP runtimeConfigFile must remain outside the Nix store.";
          }
          {
            assertion = hasPrefix "/" cfg.logDirectory;
            message = "cloudflared MCP logDirectory must be an absolute path.";
          }
          {
            assertion = isOutsideNixStore cfg.logDirectory;
            message = "cloudflared MCP logs must remain outside the Nix store.";
          }
        ];

        home.packages = [
          pkgs.cloudflared
          init
          restart
          runner
        ];

        home.activation.cloudflaredMcpRuntimeDirectories =
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run mkdir -p ${escapeShellArg cfg.logDirectory}
            run chmod 700 ${escapeShellArg cfg.logDirectory}
            run mkdir -p ${escapeShellArg (builtins.dirOf cfg.environmentFile)}
            run chmod 700 ${escapeShellArg (builtins.dirOf cfg.environmentFile)}
          '';

        launchd.agents.cloudflared-mcp-tunnel = mkIf isDarwin {
          enable = true;
          domain = "gui";
          config = {
            Label = serviceLabel;
            ProgramArguments = [ "${runner}/bin/cloudflared-mcp-tunnel-run" ];
            RunAtLoad = cfg.autoStart;
            KeepAlive = {
              SuccessfulExit = false;
            };
            ThrottleInterval = 15;
            ProcessType = "Background";
            StandardOutPath = "${cfg.logDirectory}/stdout.log";
            StandardErrorPath = "${cfg.logDirectory}/stderr.log";
          };
        };

        systemd.user.services.cloudflared-mcp-tunnel = mkIf isLinux {
          Unit = {
            Description = "Cloudflare Tunnel for repo-harness MCP";
            After = [
              "network-online.target"
              "repo-harness-mcp.service"
            ];
            Wants = [
              "network-online.target"
              "repo-harness-mcp.service"
            ];
          };
          Service = {
            ExecStart = "${runner}/bin/cloudflared-mcp-tunnel-run";
            Restart = "on-failure";
            RestartSec = 15;
          };
          Install.WantedBy = lib.optional cfg.autoStart "default.target";
        };

        home.shellAliases = {
          rh-cloudflared-mcp-init = "cloudflared-mcp-tunnel-init";
          rh-cloudflared-mcp-restart = "cloudflared-mcp-tunnel-restart";
        };
      };
    };
}
