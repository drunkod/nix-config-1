{
  flake.modules.homeManager.touchpoint-mcp-proxy =
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

      cfg = config.services.touchpoint-mcp-proxy;
      touchpointCfg = config.services.touchpoint;
      localOrigin = "http://127.0.0.1:${toString cfg.port}";
      stateDirectory = cfg.stateDirectory;
      npmCache = "${stateDirectory}/npm-cache";
      touchpointCommand = "${config.home.profileDirectory}/bin/touchpoint-mcp-nix";

      cfProxyPid = "${stateDirectory}/cloudflare-proxy.pid";
      cfTunnelPid = "${stateDirectory}/cloudflare-tunnel.pid";
      cfUrlFile = "${stateDirectory}/cloudflare-url";
      cfProxyLog = "${stateDirectory}/cloudflare-proxy.log";
      cfTunnelLog = "${stateDirectory}/cloudflare-tunnel.log";

      glaPid = "${stateDirectory}/gla-proxy.pid";
      glaUrlFile = "${stateDirectory}/gla-url";
      glaLog = "${stateDirectory}/gla-proxy.log";

      isOutsideNixStore = path: path != "/nix/store" && !hasPrefix "/nix/store/" path;

      localProxy = pkgs.writeShellApplication {
        name = "touchpoint-mcp-proxy-local";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.nodejs
        ];
        text = ''
          set -euo pipefail

          command=${escapeShellArg touchpointCommand}
          [ -x "$command" ] || {
            echo "Touchpoint MCP wrapper is unavailable; rebuild m1-min first." >&2
            exit 127
          }

          export PYTHONUNBUFFERED=1
          export npm_config_cache=${escapeShellArg npmCache}
          mkdir -p "$npm_config_cache"

          # Keep the default stateful MCP session. Touchpoint's MCP layer keeps
          # short element aliases and snapshot baselines in memory.
          exec ${pkgs.nodejs}/bin/npx --yes mcp-proxy \
            --port ${toString cfg.port} \
            --server stream \
            -- \
            "$command"
        '';
      };

      stop = pkgs.writeShellApplication {
        name = "touchpoint-mcp-proxy-stop";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          set -euo pipefail

          stop_owned_pid() {
            pid_file="$1"
            needle="$2"
            [ -f "$pid_file" ] || return 0
            pid="$(<"$pid_file")"
            case "$pid" in
              ""|*[!0-9]*) rm -f "$pid_file"; return 0 ;;
            esac
            cmd="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
            case "$cmd" in
              *"$needle"*)
                /usr/bin/pkill -TERM -P "$pid" 2>/dev/null || true
                kill "$pid" 2>/dev/null || true
                ;;
              "") ;;
              *) echo "Touchpoint MCP proxy: stale PID $pid does not match $needle; not killing it" >&2 ;;
            esac
            rm -f "$pid_file"
          }

          stop_owned_pid ${escapeShellArg cfTunnelPid} cloudflared
          stop_owned_pid ${escapeShellArg cfProxyPid} mcp-proxy
          stop_owned_pid ${escapeShellArg glaPid} mcp-proxy
          rm -f ${escapeShellArg cfUrlFile} ${escapeShellArg glaUrlFile}
        '';
      };

      cloudflareRestart = pkgs.writeShellApplication {
        name = "touchpoint-mcp-cloudflare-restart";
        runtimeInputs = [
          pkgs.cloudflared
          pkgs.coreutils
          pkgs.curl
          pkgs.gnugrep
          pkgs.nodejs
        ];
        text = ''
          set -euo pipefail

          state_dir=${escapeShellArg stateDirectory}
          local_origin=${escapeShellArg localOrigin}
          proxy_pid_file=${escapeShellArg cfProxyPid}
          tunnel_pid_file=${escapeShellArg cfTunnelPid}
          url_file=${escapeShellArg cfUrlFile}
          proxy_log=${escapeShellArg cfProxyLog}
          tunnel_log=${escapeShellArg cfTunnelLog}

          ${stop}/bin/touchpoint-mcp-proxy-stop
          mkdir -p "$state_dir" ${escapeShellArg npmCache}
          chmod 700 "$state_dir" ${escapeShellArg npmCache}
          rm -f "$proxy_log" "$tunnel_log"

          nohup ${localProxy}/bin/touchpoint-mcp-proxy-local >"$proxy_log" 2>&1 &
          proxy_pid=$!
          printf '%s\n' "$proxy_pid" >"$proxy_pid_file"
          chmod 600 "$proxy_pid_file"

          local_ready=0
          for ((attempt = 0; attempt < 30; attempt++)); do
            if ! kill -0 "$proxy_pid" 2>/dev/null; then
              echo "Touchpoint MCP proxy exited before becoming ready" >&2
              tail -n 80 "$proxy_log" >&2 || true
              exit 1
            fi
            if curl --fail --silent --max-time 2 "$local_origin/ping" >/dev/null 2>&1; then
              local_ready=1
              break
            fi
            sleep 1
          done
          [ "$local_ready" -eq 1 ] || {
            echo "Touchpoint MCP proxy did not become ready on $local_origin" >&2
            tail -n 80 "$proxy_log" >&2 || true
            exit 1
          }

          nohup ${pkgs.cloudflared}/bin/cloudflared tunnel \
            --protocol http2 \
            --loglevel info \
            --url "$local_origin" \
            >"$tunnel_log" 2>&1 &
          tunnel_pid=$!
          printf '%s\n' "$tunnel_pid" >"$tunnel_pid_file"
          chmod 600 "$tunnel_pid_file"

          quick_url=""
          registered=0
          deadline=$((SECONDS + ${toString cfg.waitSeconds}))
          while [ "$SECONDS" -lt "$deadline" ]; do
            if ! kill -0 "$tunnel_pid" 2>/dev/null; then
              echo "Cloudflare Quick Tunnel exited before becoming ready" >&2
              tail -n 80 "$tunnel_log" >&2 || true
              exit 1
            fi
            [ -n "$quick_url" ] || quick_url="$(grep -Eom1 'https://[A-Za-z0-9-]+\.trycloudflare\.com' "$tunnel_log" || true)"
            if grep -q 'Registered tunnel connection.*protocol=http2' "$tunnel_log"; then
              registered=1
            fi
            [ -n "$quick_url" ] && [ "$registered" -eq 1 ] && break
            sleep 1
          done

          [ -n "$quick_url" ] && [ "$registered" -eq 1 ] || {
            echo "Timed out waiting for trycloudflare.com tunnel" >&2
            tail -n 80 "$tunnel_log" >&2 || true
            ${stop}/bin/touchpoint-mcp-proxy-stop
            exit 1
          }

          sleep ${toString cfg.publishGraceSeconds}
          public_ready=0
          deadline=$((SECONDS + ${toString cfg.publicReadySeconds}))
          while [ "$SECONDS" -lt "$deadline" ]; do
            if curl --fail --silent --max-time 8 "$quick_url/ping" >/dev/null 2>&1; then
              public_ready=1
              break
            fi
            sleep 2
          done
          [ "$public_ready" -eq 1 ] || {
            echo "TryCloudflare hostname did not become reachable" >&2
            ${stop}/bin/touchpoint-mcp-proxy-stop
            exit 1
          }

          printf '%s\n' "$quick_url" >"$url_file"
          chmod 600 "$url_file"

          echo
          echo "Touchpoint MCP via Cloudflare Quick Tunnel is ready"
          printf 'ChatGPT MCP URL: %s/mcp\n' "$quick_url"
          printf 'Ping:            %s/ping\n' "$quick_url"
          echo "WARNING: this developer endpoint has no authentication and can control your desktop."
        '';
      };

      cloudflareUrl = pkgs.writeShellApplication {
        name = "touchpoint-mcp-cloudflare-url";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          set -euo pipefail
          file=${escapeShellArg cfUrlFile}
          [ -s "$file" ] || { echo "No Cloudflare URL; run tp-mcp-cf-restart" >&2; exit 1; }
          printf '%s/mcp\n' "$(<"$file")"
        '';
      };

      cloudflareTest = pkgs.writeShellApplication {
        name = "touchpoint-mcp-cloudflare-test";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          set -euo pipefail
          file=${escapeShellArg cfUrlFile}
          [ -s "$file" ] || { echo "No Cloudflare URL; run tp-mcp-cf-restart" >&2; exit 1; }
          url="$(<"$file")"
          curl --fail --silent --show-error --max-time 10 "$url/ping"
          echo
          printf 'MCP: %s/mcp\n' "$url"
        '';
      };

      glaRestart = pkgs.writeShellApplication {
        name = "touchpoint-mcp-gla-restart";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.gnugrep
          pkgs.nodejs
        ];
        text = ''
          set -euo pipefail

          state_dir=${escapeShellArg stateDirectory}
          pid_file=${escapeShellArg glaPid}
          url_file=${escapeShellArg glaUrlFile}
          log_file=${escapeShellArg glaLog}
          command=${escapeShellArg touchpointCommand}

          ${stop}/bin/touchpoint-mcp-proxy-stop
          mkdir -p "$state_dir" ${escapeShellArg npmCache}
          chmod 700 "$state_dir" ${escapeShellArg npmCache}
          rm -f "$log_file" "$url_file"

          [ -x "$command" ] || {
            echo "Touchpoint MCP wrapper is unavailable; rebuild m1-min first." >&2
            exit 127
          }

          export PYTHONUNBUFFERED=1
          export npm_config_cache=${escapeShellArg npmCache}

          nohup ${pkgs.nodejs}/bin/npx --yes mcp-proxy \
            --port ${toString cfg.port} \
            --server stream \
            --tunnel \
            -- \
            "$command" \
            >"$log_file" 2>&1 &
          pid=$!
          printf '%s\n' "$pid" >"$pid_file"
          chmod 600 "$pid_file"

          public_url=""
          deadline=$((SECONDS + ${toString cfg.waitSeconds}))
          while [ "$SECONDS" -lt "$deadline" ]; do
            if ! kill -0 "$pid" 2>/dev/null; then
              echo "mcp-proxy public tunnel exited before becoming ready" >&2
              tail -n 100 "$log_file" >&2 || true
              exit 1
            fi
            public_url="$(grep -Eom1 'https://[A-Za-z0-9-]+\.tunnel\.gla\.ma' "$log_file" || true)"
            [ -n "$public_url" ] && break
            sleep 1
          done

          [ -n "$public_url" ] || {
            echo "Timed out waiting for tunnel.gla.ma URL" >&2
            tail -n 100 "$log_file" >&2 || true
            ${stop}/bin/touchpoint-mcp-proxy-stop
            exit 1
          }

          public_ready=0
          deadline=$((SECONDS + ${toString cfg.publicReadySeconds}))
          while [ "$SECONDS" -lt "$deadline" ]; do
            if curl --fail --silent --max-time 8 "$public_url/ping" >/dev/null 2>&1; then
              public_ready=1
              break
            fi
            sleep 2
          done
          [ "$public_ready" -eq 1 ] || {
            echo "tunnel.gla.ma endpoint did not become reachable" >&2
            ${stop}/bin/touchpoint-mcp-proxy-stop
            exit 1
          }

          printf '%s\n' "$public_url" >"$url_file"
          chmod 600 "$url_file"

          echo
          echo "Touchpoint MCP via mcp-proxy Public Tunnel is ready"
          printf 'Tunnel root:     %s\n' "$public_url"
          printf 'ChatGPT MCP URL: %s/mcp\n' "$public_url"
          echo "Example shape: https://abcdefghij.tunnel.gla.ma/mcp"
          echo "WARNING: this developer endpoint has no authentication and can control your desktop."
        '';
      };

      glaUrl = pkgs.writeShellApplication {
        name = "touchpoint-mcp-gla-url";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          set -euo pipefail
          file=${escapeShellArg glaUrlFile}
          [ -s "$file" ] || { echo "No gla.ma URL; run tp-mcp-gla-restart" >&2; exit 1; }
          printf '%s/mcp\n' "$(<"$file")"
        '';
      };

      glaTest = pkgs.writeShellApplication {
        name = "touchpoint-mcp-gla-test";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          set -euo pipefail
          file=${escapeShellArg glaUrlFile}
          [ -s "$file" ] || { echo "No gla.ma URL; run tp-mcp-gla-restart" >&2; exit 1; }
          url="$(<"$file")"
          curl --fail --silent --show-error --max-time 10 "$url/ping"
          echo
          printf 'MCP: %s/mcp\n' "$url"
        '';
      };
    in
    {
      options.services.touchpoint-mcp-proxy = {
        enable = mkEnableOption "mcp-proxy HTTP/public tunnel wrappers for Touchpoint";

        port = mkOption {
          type = types.port;
          default = 8081;
          description = "Loopback port used by mcp-proxy.";
        };

        stateDirectory = mkOption {
          type = types.str;
          default = "${config.home.homeDirectory}/.local/state/touchpoint-mcp-proxy";
          description = "Runtime logs, PIDs, npm cache, and temporary public URLs.";
        };

        waitSeconds = mkOption {
          type = types.ints.between 10 120;
          default = 45;
        };

        publishGraceSeconds = mkOption {
          type = types.ints.between 0 60;
          default = 5;
        };

        publicReadySeconds = mkOption {
          type = types.ints.between 10 180;
          default = 90;
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = touchpointCfg.enable;
            message = "services.touchpoint-mcp-proxy requires services.touchpoint.enable = true.";
          }
          {
            assertion = hasPrefix "/" cfg.stateDirectory && isOutsideNixStore cfg.stateDirectory;
            message = "Touchpoint MCP proxy stateDirectory must be an absolute path outside the Nix store.";
          }
        ];

        home.packages = [
          pkgs.cloudflared
          pkgs.nodejs
          localProxy
          stop
          cloudflareRestart
          cloudflareUrl
          cloudflareTest
          glaRestart
          glaUrl
          glaTest
        ];

        home.activation.touchpointMcpProxyRuntimeDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p ${escapeShellArg cfg.stateDirectory}
          run chmod 700 ${escapeShellArg cfg.stateDirectory}
        '';

        home.shellAliases = {
          tp-mcp-local = "${localProxy}/bin/touchpoint-mcp-proxy-local";
          tp-mcp-stop = "${stop}/bin/touchpoint-mcp-proxy-stop";
          tp-mcp-cf-restart = "${cloudflareRestart}/bin/touchpoint-mcp-cloudflare-restart";
          tp-mcp-cf-url = "${cloudflareUrl}/bin/touchpoint-mcp-cloudflare-url";
          tp-mcp-cf-test = "${cloudflareTest}/bin/touchpoint-mcp-cloudflare-test";
          tp-mcp-gla-restart = "${glaRestart}/bin/touchpoint-mcp-gla-restart";
          tp-mcp-gla-url = "${glaUrl}/bin/touchpoint-mcp-gla-url";
          tp-mcp-gla-test = "${glaTest}/bin/touchpoint-mcp-gla-test";
        };
      };
    };
}
