{
  flake.modules.homeManager.tududi-chatgpt-quick =
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

      cfg = config.services.tududi-chatgpt-quick;
      tududiCfg = config.services.tududi;
      appDir = "${tududiCfg.package}/libexec/tududi/backend";
      nodeBin = "${tududiCfg.nodePackage}/bin/node";
      gatewayOrigin = "http://127.0.0.1:${toString cfg.port}";
      stateDirectory = cfg.stateDirectory;
      gatewayLog = "${stateDirectory}/gateway.log";
      tunnelLog = "${stateDirectory}/cloudflared.log";
      urlFile = "${stateDirectory}/public-url";
      gatewayPidFile = "${stateDirectory}/gateway.pid";
      tunnelPidFile = "${stateDirectory}/cloudflared.pid";
      healthBin = "${config.home.profileDirectory}/bin/tududi-health";
      restartBin = "${config.home.profileDirectory}/bin/tududi-restart";
      apiTokenFile =
        if tududiCfg.sops.enable then config.sops.secrets."tududi-api-token".path else tududiCfg.apiTokenFile;
      isOutsideNixStore = path: path != "/nix/store" && !hasPrefix "/nix/store/" path;

      gatewayScript = pkgs.writeText "tududi-chatgpt-mcp-mvp.js" ''
        'use strict';

        const path = require('node:path');
        const express = require('express');
        const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
        const {
          StreamableHTTPServerTransport,
        } = require('@modelcontextprotocol/sdk/server/streamableHttp.js');
        const {
          CallToolRequestSchema,
          ListToolsRequestSchema,
        } = require('@modelcontextprotocol/sdk/types.js');

        const appDir = process.env.TUDUDI_APP_DIR;
        const host = process.env.TUDUDI_MCP_MVP_HOST || '127.0.0.1';
        const port = Number(process.env.TUDUDI_MCP_MVP_PORT || '3003');
        const apiTokenValue = process.env.TUDUDI_API_TOKEN;

        if (!appDir || !apiTokenValue) {
          console.error('Tududi ChatGPT MVP: required runtime configuration is missing');
          process.exit(1);
        }

        const { User } = require(path.join(appDir, 'models'));
        const { findValidTokenByValue } = require(
          path.join(appDir, 'modules/users/apiTokenService')
        );
        const { registerAllTools } = require(
          path.join(appDir, 'modules/mcp/toolRegistry')
        );

        async function resolveUser() {
          const token = await findValidTokenByValue(apiTokenValue);
          if (!token) {
            throw new Error('configured Tududi API token is invalid or expired');
          }
          const user = await User.findByPk(token.user_id);
          if (!user) {
            throw new Error('configured Tududi API token has no user');
          }
          return user;
        }

        function createMcpServer(context) {
          const server = new Server(
            {
              name: process.env.MCP_SERVER_NAME || 'tududi-chatgpt-mvp',
              version: '0.0.1-mvp',
            },
            {
              capabilities: { tools: {} },
            }
          );
          const tools = [];

          server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools }));
          server.setRequestHandler(CallToolRequestSchema, async (request) => {
            const tool = tools.find((candidate) => candidate.name === request.params.name);
            if (!tool) {
              throw new Error('Unknown tool: ' + request.params.name);
            }
            try {
              return await tool.handler(request.params.arguments || {}, context);
            } catch (error) {
              return {
                content: [{ type: 'text', text: 'Error: ' + error.message }],
                isError: true,
              };
            }
          });

          registerAllTools(server, context, tools);
          return server;
        }

        async function main() {
          const user = await resolveUser();
          const context = { userId: user.id, user };
          const app = express();

          app.use(express.json({ limit: '2mb' }));

          app.get('/api/health', (_req, res) => {
            res.json({ status: 'ok', mode: 'UNSAFE_CHATGPT_MVP' });
          });

          app.get('/api/mcp/status', (_req, res) => {
            res.json({ enabled: true, mode: 'UNSAFE_CHATGPT_MVP' });
          });

          app.post('/api/mcp', async (req, res) => {
            try {
              const server = createMcpServer(context);
              const transport = new StreamableHTTPServerTransport({
                sessionIdGenerator: undefined,
                // Quick Tunnels do not support long-lived SSE. Force the
                // request/response form of Streamable HTTP for this MVP.
                enableJsonResponse: true,
              });
              await server.connect(transport);
              await transport.handleRequest(req, res, req.body);
            } catch (error) {
              console.error('Tududi ChatGPT MVP MCP error:', error);
              if (!res.headersSent) {
                res.status(500).json({ error: 'MCP request failed' });
              }
            }
          });

          app.all('/api/mcp', (_req, res) => {
            res.status(405).json({ error: 'This MVP only supports MCP POST requests' });
          });

          app.use((_req, res) => {
            res.status(404).json({ error: 'Not Found' });
          });

          const listener = app.listen(port, host, () => {
            console.log('Tududi ChatGPT MVP gateway listening on http://' + host + ':' + port);
            console.log('WARNING: authentication is intentionally disabled for temporary testing');
          });
          listener.keepAliveTimeout = 120000;
          listener.headersTimeout = 125000;
        }

        main().catch((error) => {
          console.error('Tududi ChatGPT MVP startup failed:', error);
          process.exit(1);
        });
      '';

      gateway = pkgs.writeShellApplication {
        name = "tududi-chatgpt-mcp-mvp-gateway";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          set -euo pipefail

          token_file=${escapeShellArg (if apiTokenFile == null then "" else apiTokenFile)}
          [ -n "$token_file" ] && [ -s "$token_file" ] || {
            echo "Tududi ChatGPT MVP: API token is not configured" >&2
            exit 1
          }

          export NODE_ENV=production
          export DB_FILE=${escapeShellArg tududiCfg.dbFile}
          export TUDUDI_UPLOAD_PATH=${escapeShellArg tududiCfg.uploadDirectory}
          export FF_ENABLE_MCP=true
          export MCP_SERVER_NAME="tududi-chatgpt-mvp"
          export NODE_PATH=${escapeShellArg "${tududiCfg.package}/libexec/tududi/node_modules"}
          export TUDUDI_APP_DIR=${escapeShellArg appDir}
          export TUDUDI_MCP_MVP_HOST=127.0.0.1
          export TUDUDI_MCP_MVP_PORT=${escapeShellArg (toString cfg.port)}
          TUDUDI_API_TOKEN="$(<"$token_file")"
          export TUDUDI_API_TOKEN

          cd ${escapeShellArg appDir}
          exec ${nodeBin} ${gatewayScript}
        '';
      };

      quickRestart = pkgs.writeShellApplication {
        name = "tududi-chatgpt-quick-restart";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          gnugrep
        ];
        text = ''
          set -euo pipefail

          state_dir=${escapeShellArg stateDirectory}
          gateway_origin=${escapeShellArg gatewayOrigin}
          gateway_log=${escapeShellArg gatewayLog}
          tunnel_log=${escapeShellArg tunnelLog}
          url_file=${escapeShellArg urlFile}
          gateway_pid_file=${escapeShellArg gatewayPidFile}
          tunnel_pid_file=${escapeShellArg tunnelPidFile}
          gateway_script=${escapeShellArg (toString gatewayScript)}
          health=${escapeShellArg healthBin}
          restart=${escapeShellArg restartBin}

          is_gateway_pid() {
            candidate="$1"
            case "$candidate" in ""|*[!0-9]*) return 1 ;; esac
            cmd="$(/bin/ps -p "$candidate" -o command= 2>/dev/null || true)"
            case "$cmd" in *"$gateway_script"*) return 0 ;; *) return 1 ;; esac
          }

          is_tunnel_pid() {
            candidate="$1"
            case "$candidate" in ""|*[!0-9]*) return 1 ;; esac
            cmd="$(/bin/ps -p "$candidate" -o command= 2>/dev/null || true)"
            case "$cmd" in *cloudflared*tunnel*"--url $gateway_origin"*) return 0 ;; *) return 1 ;; esac
          }

          stop_pid_file() {
            pid_file="$1"
            kind="$2"
            [ -f "$pid_file" ] || return 0
            pid="$(<"$pid_file")"
            if [ "$kind" = gateway ] && is_gateway_pid "$pid"; then
              kill "$pid" 2>/dev/null || true
            elif [ "$kind" = tunnel ] && is_tunnel_pid "$pid"; then
              kill "$pid" 2>/dev/null || true
            elif [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
              echo "Tududi ChatGPT MVP: stale $kind PID file; not killing PID $pid" >&2
            fi
            rm -f "$pid_file"
          }

          for helper in "$health" "$restart"; do
            [ -x "$helper" ] || {
              echo "Tududi ChatGPT MVP: required helper is unavailable: $helper" >&2
              echo "Rebuild/activate m1-min first." >&2
              exit 127
            }
          done

          mkdir -p "$state_dir"
          chmod 700 "$state_dir"

          if ! "$health" >/dev/null 2>&1; then
            echo "Tududi ChatGPT MVP: local Tududi is not healthy; restarting it first"
            "$restart"
            ready=0
            for ((attempt = 0; attempt < 20; attempt++)); do
              if "$health" >/dev/null 2>&1; then ready=1; break; fi
              sleep 1
            done
            [ "$ready" -eq 1 ] || {
              echo "Tududi ChatGPT MVP: Tududi did not recover" >&2
              exit 1
            }
          fi

          stop_pid_file "$tunnel_pid_file" tunnel
          stop_pid_file "$gateway_pid_file" gateway
          rm -f "$url_file" "$gateway_log" "$tunnel_log"

          nohup ${gateway}/bin/tududi-chatgpt-mcp-mvp-gateway \
            >"$gateway_log" 2>&1 &
          gateway_pid=$!
          printf '%s\n' "$gateway_pid" >"$gateway_pid_file"
          chmod 600 "$gateway_pid_file"

          gateway_ready=0
          for ((attempt = 0; attempt < 20; attempt++)); do
            if ! kill -0 "$gateway_pid" 2>/dev/null; then
              echo "Tududi ChatGPT MVP: gateway exited" >&2
              tail -n 80 "$gateway_log" >&2 || true
              exit 1
            fi
            if curl --fail --silent --max-time 2 "$gateway_origin/api/health" >/dev/null 2>&1; then
              gateway_ready=1
              break
            fi
            sleep 1
          done
          [ "$gateway_ready" -eq 1 ] || {
            echo "Tududi ChatGPT MVP: gateway did not become ready" >&2
            tail -n 80 "$gateway_log" >&2 || true
            exit 1
          }

          nohup ${pkgs.cloudflared}/bin/cloudflared tunnel \
            --protocol http2 \
            --loglevel info \
            --url "$gateway_origin" \
            >"$tunnel_log" 2>&1 &
          tunnel_pid=$!
          printf '%s\n' "$tunnel_pid" >"$tunnel_pid_file"
          chmod 600 "$tunnel_pid_file"

          cleanup_on_error=1
          cleanup() {
            status=$?
            trap - EXIT
            if [ "$cleanup_on_error" -eq 1 ]; then
              is_tunnel_pid "$tunnel_pid" && kill "$tunnel_pid" 2>/dev/null || true
              is_gateway_pid "$gateway_pid" && kill "$gateway_pid" 2>/dev/null || true
              rm -f "$url_file" "$gateway_pid_file" "$tunnel_pid_file"
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
              echo "Tududi ChatGPT MVP: cloudflared exited before becoming ready" >&2
              tail -n 80 "$tunnel_log" >&2 || true
              exit 1
            fi
            if [ -z "$quick_url" ]; then
              quick_url="$(grep -Eom1 'https://[A-Za-z0-9-]+\.trycloudflare\.com' "$tunnel_log" || true)"
            fi
            if [ "$registered" -eq 0 ] && grep -q 'Registered tunnel connection.*protocol=http2' "$tunnel_log"; then
              registered=1
            fi
            if [ -n "$quick_url" ] && [ "$registered" -eq 1 ]; then break; fi
            sleep 1
          done

          [ -n "$quick_url" ] || {
            echo "Tududi ChatGPT MVP: timed out waiting for trycloudflare.com URL" >&2
            tail -n 80 "$tunnel_log" >&2 || true
            exit 1
          }
          [ "$registered" -eq 1 ] || {
            echo "Tududi ChatGPT MVP: HTTP/2 tunnel did not register" >&2
            tail -n 80 "$tunnel_log" >&2 || true
            exit 1
          }

          echo "Tududi ChatGPT MVP: waiting ${toString cfg.publishGraceSeconds}s for public hostname"
          sleep ${toString cfg.publishGraceSeconds}

          stable=0
          deadline=$((SECONDS + ${toString cfg.publicReadySeconds}))
          while [ "$stable" -lt ${toString cfg.probeCount} ] && [ "$SECONDS" -lt "$deadline" ]; do
            code="$(curl --silent --max-time 10 --output /dev/null --write-out '%{http_code}' \
              "$quick_url/api/health" 2>/dev/null || true)"
            if [ "$code" = 200 ]; then
              stable=$((stable + 1))
              printf 'public probe %02d/%02d: HTTP %s\n' "$stable" ${toString cfg.probeCount} "$code"
            else
              stable=0
            fi
            sleep ${toString cfg.retryIntervalSeconds}
          done

          [ "$stable" -eq ${toString cfg.probeCount} ] || {
            echo "Tududi ChatGPT MVP: public health did not become stable" >&2
            tail -n 80 "$tunnel_log" >&2 || true
            exit 1
          }

          printf '%s\n' "$quick_url" >"$url_file"
          chmod 600 "$url_file"
          cleanup_on_error=0
          trap - EXIT INT TERM

          echo
          echo "Tududi ChatGPT Quick MVP ready"
          printf 'ChatGPT MCP URL: %s/api/mcp\n' "$quick_url"
          printf 'Health:          %s/api/health\n' "$quick_url"
          printf 'Gateway log:     %s\n' "$gateway_log"
          printf 'Tunnel log:      %s\n' "$tunnel_log"
          echo
          echo "WARNING: NO AUTHENTICATION. Anyone with this URL can use your Tududi MCP tools."
          echo "Stop immediately after testing with: td-chatgpt-quick-stop"
        '';
      };

      quickTest = pkgs.writeShellApplication {
        name = "tududi-chatgpt-quick-test";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          jq
        ];
        text = ''
          set -euo pipefail
          url_file=${escapeShellArg urlFile}

          [ -s "$url_file" ] || {
            echo "Tududi ChatGPT MVP: no saved URL; run td-chatgpt-quick-restart first" >&2
            exit 1
          }
          quick_url="$(<"$url_file")"

          echo "=== public gateway health ==="
          curl --fail --silent --show-error --max-time 10 "$quick_url/api/health" | jq .

          echo "=== anonymous MCP status ==="
          curl --fail --silent --show-error --max-time 10 "$quick_url/api/mcp/status" \
            | jq -e '.enabled == true'

          echo "=== MCP initialize ==="
          response="$(curl --fail --silent --show-error --max-time 20 \
            -H 'Content-Type: application/json' \
            -H 'Accept: application/json, text/event-stream' \
            --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"tududi-chatgpt-mvp-test","version":"0.0.1"}}}' \
            "$quick_url/api/mcp")"
          printf '%s\n' "$response" | jq -e '.result.serverInfo.name != null' >/dev/null
          printf '%s\n' "$response" | jq .

          echo
          printf 'ChatGPT MCP URL: %s/api/mcp\n' "$quick_url"
          echo "MVP test passed"
        '';
      };

      quickUrl = pkgs.writeShellApplication {
        name = "tududi-chatgpt-quick-url";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          set -euo pipefail
          url_file=${escapeShellArg urlFile}
          [ -s "$url_file" ] || {
            echo "Tududi ChatGPT MVP: no saved URL; run td-chatgpt-quick-restart first" >&2
            exit 1
          }
          quick_url="$(<"$url_file")"
          printf '%s/api/mcp\n' "$quick_url"
        '';
      };

      quickStop = pkgs.writeShellApplication {
        name = "tududi-chatgpt-quick-stop";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          set -euo pipefail
          gateway_origin=${escapeShellArg gatewayOrigin}
          gateway_script=${escapeShellArg (toString gatewayScript)}
          gateway_pid_file=${escapeShellArg gatewayPidFile}
          tunnel_pid_file=${escapeShellArg tunnelPidFile}
          url_file=${escapeShellArg urlFile}

          stop_if_owned() {
            pid_file="$1"
            kind="$2"
            [ -f "$pid_file" ] || return 0
            pid="$(<"$pid_file")"
            case "$pid" in ""|*[!0-9]*) rm -f "$pid_file"; return 0 ;; esac
            cmd="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
            owned=0
            if [ "$kind" = gateway ]; then
              case "$cmd" in *"$gateway_script"*) owned=1 ;; esac
            else
              case "$cmd" in *cloudflared*tunnel*"--url $gateway_origin"*) owned=1 ;; esac
            fi
            if [ "$owned" -eq 1 ]; then
              kill "$pid" 2>/dev/null || true
            elif [ -n "$cmd" ]; then
              echo "Tududi ChatGPT MVP: stale $kind PID file; not killing PID $pid" >&2
            fi
            rm -f "$pid_file"
          }

          stop_if_owned "$tunnel_pid_file" tunnel
          stop_if_owned "$gateway_pid_file" gateway
          rm -f "$url_file"
          echo "Tududi ChatGPT Quick MVP stopped"
        '';
      };
    in
    {
      options.services.tududi-chatgpt-quick = {
        enable = mkEnableOption "UNSAFE anonymous trycloudflare.com MVP for ChatGPT -> Tududi MCP";

        port = mkOption {
          type = types.port;
          default = 3003;
          description = "Loopback port for the temporary anonymous MCP gateway.";
        };

        stateDirectory = mkOption {
          type = types.str;
          default = "${config.home.homeDirectory}/.local/state/tududi-chatgpt-quick";
          description = "State directory for the MVP gateway and Quick Tunnel.";
        };

        waitSeconds = mkOption {
          type = types.ints.between 10 120;
          default = 45;
          description = "Seconds to wait for the Quick Tunnel URL and registration.";
        };

        publishGraceSeconds = mkOption {
          type = types.ints.between 0 120;
          default = 10;
          description = "Delay after tunnel registration before public probes.";
        };

        publicReadySeconds = mkOption {
          type = types.ints.between 10 300;
          default = 90;
          description = "Seconds to wait for the public MVP endpoint.";
        };

        retryIntervalSeconds = mkOption {
          type = types.ints.between 1 30;
          default = 3;
          description = "Seconds between public health retries.";
        };

        probeCount = mkOption {
          type = types.ints.between 1 10;
          default = 2;
          description = "Consecutive public HTTP 200 probes required.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = tududiCfg.enable && tududiCfg.mcp.enable;
            message = "services.tududi-chatgpt-quick requires Tududi MCP to be enabled.";
          }
          {
            assertion = apiTokenFile != null;
            message = "services.tududi-chatgpt-quick requires a Tududi API token file.";
          }
          {
            assertion = hasPrefix "/" cfg.stateDirectory && isOutsideNixStore cfg.stateDirectory;
            message = "Tududi ChatGPT MVP stateDirectory must be absolute and outside the Nix store.";
          }
        ];

        home.packages = [
          pkgs.cloudflared
          gateway
          quickRestart
          quickStop
          quickTest
          quickUrl
        ];

        home.activation.tududiChatgptQuickRuntimeDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p ${escapeShellArg cfg.stateDirectory}
          run chmod 700 ${escapeShellArg cfg.stateDirectory}
        '';

        home.shellAliases = {
          td-chatgpt-quick-restart = "${quickRestart}/bin/tududi-chatgpt-quick-restart";
          td-chatgpt-quick-stop = "${quickStop}/bin/tududi-chatgpt-quick-stop";
          td-chatgpt-quick-test = "${quickTest}/bin/tududi-chatgpt-quick-test";
          td-chatgpt-quick-url = "${quickUrl}/bin/tududi-chatgpt-quick-url";
        };
      };
    };
}
