{
  flake.modules.homeManager.repo-harness-mcp-quick =
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

      cfg = config.services.repo-harness-mcp-quick;
      mcpCfg = config.services.repo-harness-mcp;
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      localUrlHost = if mcpCfg.host == "::1" then "[::1]" else mcpCfg.host;
      localOrigin = "http://${localUrlHost}:${toString mcpCfg.port}";
      runtimePath = "${config.home.homeDirectory}/.bun/bin:${config.home.profileDirectory}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      logFile = "${cfg.stateDirectory}/cloudflared.log";
      urlFile = "${cfg.stateDirectory}/public-url";
      pidFile = "${cfg.stateDirectory}/cloudflared.pid";
      bootstrapBin = "${config.home.profileDirectory}/bin/repo-harness-mcp-bootstrap";
      restartBin = "${config.home.profileDirectory}/bin/repo-harness-mcp-restart";
      healthBin = "${config.home.profileDirectory}/bin/repo-harness-mcp-health";
      doctorBin = "${config.home.profileDirectory}/bin/repo-harness-mcp-doctor";
      isOutsideNixStore = path: path != "/nix/store" && !hasPrefix "/nix/store/" path;

      quickRestart = pkgs.writeShellApplication {
        name = "repo-harness-mcp-quick-restart";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          gnugrep
          jq
        ];
        text = ''
          set -euo pipefail

          repo=${escapeShellArg (if mcpCfg.repoPath == null then "" else mcpCfg.repoPath)}
          local_origin=${escapeShellArg localOrigin}
          state_dir=${escapeShellArg cfg.stateDirectory}
          log_file=${escapeShellArg logFile}
          url_file=${escapeShellArg urlFile}
          pid_file=${escapeShellArg pidFile}
          bootstrap=${escapeShellArg bootstrapBin}
          restart=${escapeShellArg restartBin}
          health=${escapeShellArg healthBin}
          doctor=${escapeShellArg doctorBin}

          [ -d "$repo" ] || {
            echo "quick tunnel: repository is unavailable: $repo" >&2
            exit 1
          }

          for helper in "$bootstrap" "$restart" "$health" "$doctor"; do
            [ -x "$helper" ] || {
              echo "quick tunnel: required helper is unavailable: $helper" >&2
              echo "rebuild m1-min before using rh-mcp-quick-restart" >&2
              exit 127
            }
          done

          mkdir -p "$state_dir"
          chmod 700 "$state_dir"

          if [ "$(uname -s)" = "Darwin" ]; then
            /bin/launchctl setenv PATH ${escapeShellArg runtimePath}
          fi

          if ! curl --fail --silent --show-error --max-time 5 \
            "$local_origin/health" >/dev/null 2>&1
          then
            echo "quick tunnel: local MCP is not healthy; restarting it first"
            "$restart"
            ready=0
            for _ in $(seq 1 15); do
              if curl --fail --silent --max-time 2 "$local_origin/health" >/dev/null 2>&1; then
                ready=1
                break
              fi
              sleep 1
            done
            [ "$ready" -eq 1 ] || {
              echo "quick tunnel: local MCP health did not recover" >&2
              exit 1
            }
          fi

          # Stop the previous quick-tunnel child recorded by this helper.
          if [ -f "$pid_file" ]; then
            old_pid="$(cat "$pid_file" 2>/dev/null || true)"
            case "$old_pid" in
              ''|*[!0-9]*) ;;
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

          rm -f "$log_file" "$url_file" "$pid_file"

          nohup ${pkgs.cloudflared}/bin/cloudflared tunnel \
            --protocol http2 \
            --loglevel info \
            --url "$local_origin" \
            >"$log_file" 2>&1 &
          tunnel_pid=$!
          printf '%s\n' "$tunnel_pid" >"$pid_file"
          chmod 600 "$pid_file"

          quick_url=""
          for _ in $(seq 1 ${toString cfg.waitSeconds}); do
            if ! kill -0 "$tunnel_pid" 2>/dev/null; then
              echo "quick tunnel: cloudflared exited before publishing a URL" >&2
              tail -n 60 "$log_file" >&2 || true
              exit 1
            fi

            quick_url="$(grep -Eo 'https://[A-Za-z0-9-]+\.trycloudflare\.com' "$log_file" | head -1 || true)"
            [ -n "$quick_url" ] && break
            sleep 1
          done

          [ -n "$quick_url" ] || {
            echo "quick tunnel: timed out waiting for trycloudflare.com URL" >&2
            tail -n 60 "$log_file" >&2 || true
            exit 1
          }

          printf '%s\n' "$quick_url" >"$url_file"
          chmod 600 "$url_file"

          registered=0
          for _ in $(seq 1 ${toString cfg.waitSeconds}); do
            if grep -q 'Registered tunnel connection.*protocol=http2' "$log_file"; then
              registered=1
              break
            fi
            if ! kill -0 "$tunnel_pid" 2>/dev/null; then
              break
            fi
            sleep 1
          done

          [ "$registered" -eq 1 ] || {
            echo "quick tunnel: HTTP/2 tunnel did not register" >&2
            tail -n 80 "$log_file" >&2 || true
            exit 1
          }

          echo "quick tunnel: registered over HTTP/2"

          # Before Repo Harness learns the new hostname, 421 is expected.
          # 200 is also accepted when the same hostname is already configured.
          for i in $(seq 1 ${toString cfg.probeCount}); do
            code="$(curl --silent --show-error --max-time 10 \
              --output /dev/null --write-out '%{http_code}' \
              "$quick_url/health" || true)"
            case "$code" in
              200|421)
                printf 'pre-bootstrap probe %02d: %s\n' "$i" "$code"
                ;;
              *)
                echo "quick tunnel: public probe failed with HTTP $code" >&2
                tail -n 80 "$log_file" >&2 || true
                exit 1
                ;;
            esac
            sleep 1
          done

          "$bootstrap" \
            --repo "$repo" \
            --endpoint "$quick_url/mcp"

          if [ "$(uname -s)" = "Darwin" ]; then
            /bin/launchctl setenv PATH ${escapeShellArg runtimePath}
          fi
          "$restart"

          public_ready=0
          for _ in $(seq 1 20); do
            if curl --fail --silent --max-time 5 "$quick_url/health" >/dev/null 2>&1; then
              public_ready=1
              break
            fi
            sleep 1
          done
          [ "$public_ready" -eq 1 ] || {
            echo "quick tunnel: public health did not become ready after bootstrap" >&2
            exit 1
          }

          "$health" >/dev/null
          doctor_json="$("$doctor")"
          printf '%s\n' "$doctor_json" | jq -e '
            .status == "mcp_ready"
            and all(.layers[]; .ok == true)
          ' >/dev/null

          echo
          echo "Repo Harness Quick Tunnel ready"
          printf 'Public origin: %s\n' "$quick_url"
          printf 'ChatGPT MCP:   %s/mcp\n' "$quick_url"
          printf 'Tunnel log:    %s\n' "$log_file"
          echo
          echo "ChatGPT must use this new /mcp URL. Reconnect/reauthorize after every Quick Tunnel hostname change."
        '';
      };

      quickTest = pkgs.writeShellApplication {
        name = "repo-harness-mcp-quick-test";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          gnugrep
          jq
        ];
        text = ''
          set -euo pipefail

          local_origin=${escapeShellArg localOrigin}
          log_file=${escapeShellArg logFile}
          url_file=${escapeShellArg urlFile}
          pid_file=${escapeShellArg pidFile}
          health=${escapeShellArg healthBin}
          doctor=${escapeShellArg doctorBin}

          echo "=== local MCP ==="
          "$health"

          [ -f "$url_file" ] || {
            echo "quick tunnel: no saved URL; run rh-mcp-quick-restart" >&2
            exit 1
          }
          quick_url="$(cat "$url_file")"

          [ -f "$pid_file" ] || {
            echo "quick tunnel: no PID file; run rh-mcp-quick-restart" >&2
            exit 1
          }
          tunnel_pid="$(cat "$pid_file")"
          kill -0 "$tunnel_pid" 2>/dev/null || {
            echo "quick tunnel: cloudflared process is not running" >&2
            exit 1
          }

          grep -q 'Registered tunnel connection.*protocol=http2' "$log_file" || {
            echo "quick tunnel: no successful HTTP/2 registration in log" >&2
            exit 1
          }

          echo "=== public MCP ==="
          public_json="$(curl --fail --silent --show-error --max-time 10 "$quick_url/health")"
          printf '%s\n' "$public_json" | jq -e \
            --arg origin "$quick_url" \
            '.status == "ok" and .public_origin == $origin' >/dev/null
          printf '%s\n' "$public_json" | jq '{status, profile, auth, public_origin}'

          echo "=== doctor ==="
          doctor_json="$("$doctor")"
          printf '%s\n' "$doctor_json" | jq -e '
            .status == "mcp_ready"
            and all(.layers[]; .ok == true)
          ' >/dev/null
          printf '%s\n' "$doctor_json" | jq '{status, layers: [.layers[] | {name, ok}]}'

          echo "=== tunnel ==="
          printf 'pid: %s\n' "$tunnel_pid"
          printf 'url: %s\n' "$quick_url"
          grep -E 'Registered tunnel connection|TCP Connectivity.*PASS' "$log_file" | tail -n 6 || true

          curl --fail --silent --max-time 5 "$local_origin/health" >/dev/null
          echo "quick tunnel test passed"
        '';
      };

      quickUrl = pkgs.writeShellApplication {
        name = "repo-harness-mcp-quick-url";
        runtimeInputs = with pkgs; [ coreutils ];
        text = ''
          set -euo pipefail
          url_file=${escapeShellArg urlFile}
          [ -f "$url_file" ] || {
            echo "quick tunnel: no saved URL; run rh-mcp-quick-restart" >&2
            exit 1
          }
          quick_url="$(cat "$url_file")"
          printf '%s/mcp\n' "$quick_url"
        '';
      };

      chatgptAuth = pkgs.writeShellApplication {
        name = "repo-harness-mcp-chatgpt-auth";
        runtimeInputs = with pkgs; [
          curl
          jq
          python3
        ];
        text = ''
          set -euo pipefail

          local_origin=${escapeShellArg localOrigin}

          if [ "$(uname -s)" != "Darwin" ]; then
            echo "rh-mcp-auth currently supports the macOS clipboard/browser flow only" >&2
            exit 1
          fi

          auth_url="$(/usr/bin/pbpaste)"
          [ -n "$auth_url" ] || {
            echo "clipboard is empty" >&2
            echo "In ChatGPT click Sign in, copy the fresh Repo Harness /authorize?... URL, then run rh-mcp-auth." >&2
            exit 1
          }

          public_origin="$(curl --fail --silent --show-error --max-time 5 \
            "$local_origin/health" | jq -r '.public_origin // empty')"
          [ -n "$public_origin" ] || {
            echo "local MCP health did not report public_origin" >&2
            exit 1
          }

          # The OAuth URL contains transaction state. Clear it from the clipboard
          # as soon as it has been captured locally.
          printf '' | /usr/bin/pbcopy

          AUTH_URL="$auth_url" \
          PUBLIC_ORIGIN="$public_origin" \
          OAUTH_FILE="$HOME/.repo-harness/mcp.oauth.json" \
          ${pkgs.python3}/bin/python3 - <<'PY'
import json
import os
import pathlib
import http.client
import subprocess
import urllib.parse


def fail(message: str) -> None:
    raise SystemExit(message)


auth_url = os.environ.get("AUTH_URL", "").strip()
public_origin = os.environ.get("PUBLIC_ORIGIN", "").strip()
oauth_file = pathlib.Path(os.environ["OAUTH_FILE"])

auth = urllib.parse.urlsplit(auth_url)
origin = urllib.parse.urlsplit(public_origin)

if (
    auth.scheme != "https"
    or origin.scheme != "https"
    or auth.hostname != origin.hostname
    or auth.port != origin.port
    or auth.path != "/authorize"
    or not auth.query
):
    fail("STOP: clipboard is not the fresh Repo Harness /authorize URL")

params = dict(urllib.parse.parse_qsl(auth.query, keep_blank_values=True))
required = [
    "response_type",
    "client_id",
    "redirect_uri",
    "code_challenge",
    "code_challenge_method",
    "state",
]
missing = [key for key in required if not params.get(key)]
if missing:
    fail("Missing OAuth parameters: " + ", ".join(missing))

if params["response_type"] != "code":
    fail("Unexpected OAuth response_type")
if params["code_challenge_method"] != "S256":
    fail("Expected PKCE S256")

redirect = urllib.parse.urlsplit(params["redirect_uri"])
if redirect.scheme != "https" or redirect.hostname != "chatgpt.com":
    fail("Unexpected OAuth callback")

expected_resource = public_origin.rstrip("/") + "/mcp"
if params.get("resource") and params["resource"] != expected_resource:
    fail("OAuth resource does not match the configured MCP endpoint")

if not oauth_file.is_file():
    fail("Local OAuth file is missing; run rh-mcp-bootstrap first")
with oauth_file.open() as handle:
    oauth = json.load(handle)

passphrase = oauth.get("passphrase")
if not passphrase:
    fail("Local OAuth passphrase is missing")

params["passphrase"] = passphrase
body = urllib.parse.urlencode(params)

conn = http.client.HTTPSConnection(auth.hostname, auth.port or 443, timeout=30)
conn.request(
    "POST",
    "/authorize",
    body=body,
    headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "Origin": "https://chatgpt.com",
        "Accept": "text/html,application/xhtml+xml",
    },
)
response = conn.getresponse()
location = response.getheader("Location")
print("Authorization HTTP status:", response.status)

if response.status not in (302, 303):
    text = response.read(1000).decode("utf-8", errors="replace")
    fail("Authorization failed: " + text)
if not location:
    fail("No OAuth callback returned")

callback = urllib.parse.urlsplit(location)
if callback.scheme != "https" or callback.hostname != "chatgpt.com":
    fail("Refusing unexpected OAuth callback host")

print("OAuth accepted; opening ChatGPT callback")
subprocess.run(["/usr/bin/open", location], check=True)
PY
        '';
      };
    in
    {
      options.services.repo-harness-mcp-quick = {
        enable = mkEnableOption "ephemeral Cloudflare Quick Tunnel workflow for repo-harness MCP";

        stateDirectory = mkOption {
          type = types.str;
          default = "${config.home.homeDirectory}/.local/state/repo-harness-mcp-quick";
          description = "Private runtime directory for Quick Tunnel PID, URL, and logs.";
        };

        waitSeconds = mkOption {
          type = types.ints.between 10 120;
          default = 45;
          description = "Maximum seconds to wait for Quick Tunnel URL and HTTP/2 registration.";
        };

        probeCount = mkOption {
          type = types.ints.between 1 20;
          default = 5;
          description = "Number of stable public health probes before updating Repo Harness.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = mcpCfg.enable;
            message = "services.repo-harness-mcp-quick requires services.repo-harness-mcp.enable.";
          }
          {
            assertion = mcpCfg.profile == "coding";
            message = "services.repo-harness-mcp-quick requires the coding MCP profile.";
          }
          {
            assertion = hasPrefix "/" cfg.stateDirectory;
            message = "services.repo-harness-mcp-quick.stateDirectory must be absolute.";
          }
          {
            assertion = isOutsideNixStore cfg.stateDirectory;
            message = "Quick Tunnel runtime state must remain outside the Nix store.";
          }
        ];

        home.packages = [
          pkgs.cloudflared
          chatgptAuth
          quickRestart
          quickTest
          quickUrl
        ];

        home.activation.repoHarnessMcpQuickRuntimeDirectory =
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run mkdir -p ${escapeShellArg cfg.stateDirectory}
            run chmod 700 ${escapeShellArg cfg.stateDirectory}
          '';

        home.shellAliases = {
          rh-mcp-auth = "repo-harness-mcp-chatgpt-auth";
          rh-mcp-quick-restart = "repo-harness-mcp-quick-restart";
          rh-mcp-quick-test = "repo-harness-mcp-quick-test";
          rh-mcp-quick-url = "repo-harness-mcp-quick-url";
        };
      };
    };
}
