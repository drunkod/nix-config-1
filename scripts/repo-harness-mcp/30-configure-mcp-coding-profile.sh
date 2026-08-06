#!/usr/bin/env bash
set -euo pipefail
# Source: repo-harness coding tutorial, explicit user-scope coding setup.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

repo=""
endpoint="${REPO_HARNESS_MCP_ENDPOINT:-}"
host="${MCP_HOST:-127.0.0.1}"
port="${MCP_PORT:-8765}"
server_name="${MCP_NAME:-repo-harness-coding}"
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --endpoint) endpoint="$2"; shift 2 ;;
    --host) host="$2"; shift 2 ;;
    --port) port="$2"; shift 2 ;;
    --server-name) server_name="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help)
      echo "usage: $0 --repo PATH --endpoint https://HOST/mcp [--host 127.0.0.1] [--port 8765] [--server-name NAME] [--dry-run]"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

repo="$(resolve_repo "$repo")"
require_command repo-harness
require_command jq
require_loopback_host "$host"
require_https_mcp_endpoint "$endpoint"
[[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ] \
  || die "invalid port: $port"

cmd=(
  repo-harness mcp setup chatgpt
  --scope user
  --repo "$repo"
  --profile coding
  --grant-read-write "$repo"
  --host "$host"
  --port "$port"
  --server-name "$server_name"
  --endpoint "$endpoint"
)
run_or_print "$dry_run" "${cmd[@]}"

if [ "$dry_run" -eq 0 ]; then
  config_file="$HOME/.repo-harness/mcp.local.json"
  [ -f "$config_file" ] || die "expected config was not created: $config_file"
  jq -e '
    .scope == "user"
    and .profile == "coding"
    and .coding.enabled == true
    and (.chatgpt.endpoint | endswith("/mcp"))
  ' "$config_file" >/dev/null || die "generated MCP config does not match the coding contract"
  log "coding profile configured with an explicit read-write grant"
  log "OAuth passphrase remains local; read it directly from ~/.repo-harness/mcp.oauth.json"
fi
