{
  flake.modules.homeManager.tududi-mcp-quick =
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

      cfg = config.services.tududi-mcp-quick;
      tududiCfg = config.services.tududi;
      bracketHost = host: if host == "::1" then "[::1]" else host;
      localOrigin = "http://${bracketHost tududiCfg.host}:${toString tududiCfg.port}";
      stateDirectory = cfg.stateDirectory;
      logFile = "${stateDirectory}/cloudflared.log";
      urlFile = "${stateDirectory}/public-url";
      pidFile = "${stateDirectory}/cloudflared.pid";
      healthBin = "${config.home.profileDirectory}/bin/tududi-health";
      restartBin = "${config.home.profileDirectory}/bin/tududi-restart";
      apiTokenFile =
        if tududiCfg.sops.enable then config.sops.secrets."tududi-api-token".path else tududiCfg.apiTokenFile;
      isOutsideNixStore = path: path != "/nix/store" && !hasPrefix "/nix/store/" path;

      quickRestart = pkgs.writeShellApplication {
        name = "tududi-mcp-quick-restart";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          gnugrep
        ];
        text = ''
          set -euo pipefail

          local_origin=${escapeShellArg localOrigin}
          state_dir=${escapeShellArg stateDirectory}
          log_file=${escapeShellArg logFile}
          url_file=${escapeShellArg urlFile}
          pid_file=${escapeShellArg pidFile}
          health=${escapeShellArg healthBin}
          restart=${escapeShellArg restartBin}

          for helper in "$health" "$restart"; do
            [ -x "$helper" ] || {
              echo "Tududi Quick Tunnel: required helper is unavailable: $helper" >&2
              echo "Rebuild/activate m1-min before using td-mcp-quick-restart." >&2
              exit 127
            }
          done

          mkdir -p "$state_dir"
          chmod 700 "$state_dir"

          if ! "$health" >/dev/null 2>&1; then
            echo "Tududi Quick Tunnel: local Tududi is not healthy; restarting it first"
            "$restart"
            local_ready=0
            for _ in $(seq 1 20); do
              if curl --fail --silent --max-time 2 "$local_origin/api/health" >/dev/null 2>&1; then
                local_ready=1
                break
              fi
              sleep 1
            done
            [ "$local_ready" -eq 1 ] || {
              echo "Tududi Quick Tunnel: local /api/health did not recover" >&2
              exit 1
            }
          fi

          if [ -f "$pid_file" ]; then
            old_pid="$(cat "$pid_file" 2>/dev/null || true)"
            case "$old_pid" in
              ""|*[!0-9]*) ;;
              *)
                if kill -0 "$old_pid" 2>/dev/null; then
                  kill "$old_pid" 2>/dev/null || true
                  for _ in $(seq 1 10); do
                    kill -0 "$old_pid" 2>/dev/null || break
                    sleep 1
                  done
                fi
                ;;
            esac
          fi

          if [ "$(uname -s)" = "Darwin" ]; then
            for old_pid in $(/usr/bin/pgrep -f "cloudflared tunnel.*--url $local_origin" 2>/dev/null || true); do
              [ "$old_pid" = "$$" ] && continue
              kill "$old_pid" 2>/dev/null || true
            done
            sleep 1
          fi

          rm -f "$log_file" "$url_file" "$pid_file"

          nohup ${pkgs.cloudflared}/bin/cloudflared tunnel \
            --protocol http2 \
            --loglevel info \
            --url "$local_origin" \
            >"$log_file" 2>&1 &
          tunnel_pid=$!
          printf '%s\n' "$tunnel_pid" >"$pid_file"
          chmod 600 "$pid_file"

          cleanup_on_error=1
          cleanup() {
            status=$?
            trap - EXIT
            if [ "$cleanup_on_error" -eq 1 ]; then
              if kill -0 "$tunnel_pid" 2>/dev/null; then
                kill "$tunnel_pid" 2>/dev/null || true
              fi
              rm -f "$url_file" "$pid_file"
            fi
            exit "$status"
          }
          trap cleanup EXIT
          trap 'exit 130' INT
          trap 'exit 143' TERM

          quick_url=""
          registered=0
          deadline=$((SECONDS + ${toString cfg.waitSeconds}))
          while [ "$SECONDS" -lt "$deadline" ]; do
            if ! kill -0 "$tunnel_pid" 2>/dev/null; then
              echo "Tududi Quick Tunnel: cloudflared exited before becoming ready" >&2
              tail -n 80 "$log_file" >&2 || true
              exit 1
            fi
            if [ -z "$quick_url" ]; then
              quick_url="$(grep -Eo 'https://[A-Za-z0-9-]+\.trycloudflare\.com' "$log_file" | head -1 || true)"
            fi
            if [ "$registered" -eq 0 ] && grep -q 'Registered tunnel connection.*protocol=http2' "$log_file"; then
              registered=1
            fi
            if [ -n "$quick_url" ] && [ "$registered" -eq 1 ]; then
              break
            fi
            sleep 1
          done

          [ -n "$quick_url" ] || {
            echo "Tududi Quick Tunnel: timed out waiting for trycloudflare.com URL" >&2
            tail -n 80 "$log_file" >&2 || true
            exit 1
          }
          [ "$registered" -eq 1 ] || {
            echo "Tududi Quick Tunnel: HTTP/2 tunnel did not register" >&2
            tail -n 80 "$log_file" >&2 || true
            exit 1
          }

          echo "Tududi Quick Tunnel: waiting ${toString cfg.publishGraceSeconds}s for public hostname publication"
          sleep ${toString cfg.publishGraceSeconds}

          stable=0
          deadline=$((SECONDS + ${toString cfg.publicReadySeconds}))
          while [ "$stable" -lt ${toString cfg.probeCount} ] && [ "$SECONDS" -lt "$deadline" ]; do
            code="$(curl --silent --max-time 10 --output /dev/null --write-out '%{http_code}' \
              "$quick_url/api/health" 2>/dev/null || true)"
            case "$code" in
              200)
                stable=$((stable + 1))
                printf 'public probe %02d/%02d: HTTP %s\n' "$stable" ${toString cfg.probeCount} "$code"
                ;;
              *)
                stable=0
                ;;
            esac
            sleep ${toString cfg.retryIntervalSeconds}
          done

          [ "$stable" -eq ${toString cfg.probeCount} ] || {
            echo "Tududi Quick Tunnel: public /api/health did not become stable" >&2
            tail -n 80 "$log_file" >&2 || true
            exit 1
          }

          printf '%s\n' "$quick_url" >"$url_file"
          chmod 600 "$url_file"
          cleanup_on_error=0
          trap - EXIT INT TERM

          echo
          echo "Tududi Quick Tunnel ready"
          printf 'Public origin: %s\n' "$quick_url"
          printf 'Remote MCP:    %s/api/mcp\n' "$quick_url"
          printf 'Health:        %s/api/health\n' "$quick_url"
          printf 'Tunnel log:    %s\n' "$log_file"
          echo "Authentication: Authorization: Bearer <Tududi tt_ API token>"
          echo
          echo "Security note: this Quick Tunnel publishes the complete Tududi HTTP origin, not only /api/mcp."
        '';
      };

      quickTest = pkgs.writeShellApplication {
        name = "tududi-mcp-quick-test";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          jq
        ];
        text = ''
          set -euo pipefail

          url_file=${escapeShellArg urlFile}
          token_file=${escapeShellArg (if apiTokenFile == null then "" else apiTokenFile)}

          echo "=== local Tududi ==="
          ${healthBin}

          [ -s "$url_file" ] || {
            echo "Tududi Quick Tunnel: no saved URL; run td-mcp-quick-restart first" >&2
            exit 1
          }
          quick_url="$(cat "$url_file")"

          echo "=== public health ==="
          curl --fail --silent --show-error --max-time 10 "$quick_url/api/health" | jq .

          echo "=== authenticated MCP status ==="
          if [ -n "$token_file" ] && [ -s "$token_file" ]; then
            header_file="$(mktemp)"
            trap 'rm -f "$header_file"' EXIT
            chmod 600 "$header_file"
            printf 'Authorization: Bearer %s\n' "$(cat "$token_file")" >"$header_file"
            curl --fail --silent --show-error --max-time 10 \
              -H "@$header_file" \
              "$quick_url/api/mcp/status" | jq .
            rm -f "$header_file"
            trap - EXIT
          else
            echo "skipped: no Tududi API token file is configured yet"
          fi

          echo "=== remote MCP endpoint ==="
          printf '%s/api/mcp\n' "$quick_url"
          echo "Tududi Quick Tunnel test passed"
        '';
      };

      quickUrl = pkgs.writeShellApplication {
        name = "tududi-mcp-quick-url";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          set -euo pipefail
          url_file=${escapeShellArg urlFile}
          [ -s "$url_file" ] || {
            echo "Tududi Quick Tunnel: no saved URL; run td-mcp-quick-restart first" >&2
            exit 1
          }
          printf '%s/api/mcp\n' "$(cat "$url_file")"
        '';
      };

      quickStop = pkgs.writeShellApplication {
        name = "tududi-mcp-quick-stop";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          set -euo pipefail
          pid_file=${escapeShellArg pidFile}
          url_file=${escapeShellArg urlFile}
          [ -f "$pid_file" ] || {
            rm -f "$url_file"
            exit 0
          }
          pid="$(cat "$pid_file" 2>/dev/null || true)"
          case "$pid" in
            ""|*[!0-9]*) ;;
            *) kill "$pid" 2>/dev/null || true ;;
          esac
          rm -f "$pid_file" "$url_file"
        '';
      };
    in
    {
      options.services.tududi-mcp-quick = {
        enable = mkEnableOption "ephemeral Cloudflare Quick Tunnel for Tududi MCP";

        stateDirectory = mkOption {
          type = types.str;
          default = "${config.home.homeDirectory}/.local/state/tududi-mcp-quick";
          description = "State directory for Quick Tunnel PID, URL, and logs.";
        };

        waitSeconds = mkOption {
          type = types.ints.between 10 120;
          default = 45;
          description = "Maximum seconds to wait for the generated URL and HTTP/2 registration.";
        };

        publishGraceSeconds = mkOption {
          type = types.ints.between 0 120;
          default = 20;
          description = "Quiet delay after HTTP/2 registration before the first public hostname lookup.";
        };

        publicReadySeconds = mkOption {
          type = types.ints.between 10 300;
          default = 120;
          description = "Maximum seconds to wait for the public Tududi health endpoint.";
        };

        retryIntervalSeconds = mkOption {
          type = types.ints.between 1 30;
          default = 5;
          description = "Seconds between public health retries.";
        };

        probeCount = mkOption {
          type = types.ints.between 1 20;
          default = 3;
          description = "Number of consecutive HTTP 200 public health responses required before success.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = tududiCfg.enable;
            message = "services.tududi-mcp-quick requires services.tududi.enable = true.";
          }
          {
            assertion = hasPrefix "/" cfg.stateDirectory && isOutsideNixStore cfg.stateDirectory;
            message = "Tududi Quick Tunnel stateDirectory must be an absolute path outside the Nix store.";
          }
        ];

        home.packages = [
          pkgs.cloudflared
          quickRestart
          quickStop
          quickTest
          quickUrl
        ];

        home.activation.tududiMcpQuickRuntimeDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p ${escapeShellArg cfg.stateDirectory}
          run chmod 700 ${escapeShellArg cfg.stateDirectory}
        '';

        home.shellAliases = {
          td-mcp-quick-restart = "${quickRestart}/bin/tududi-mcp-quick-restart";
          td-mcp-quick-stop = "${quickStop}/bin/tududi-mcp-quick-stop";
          td-mcp-quick-test = "${quickTest}/bin/tududi-mcp-quick-test";
          td-mcp-quick-url = "${quickUrl}/bin/tududi-mcp-quick-url";
        };
      };
    };
}
