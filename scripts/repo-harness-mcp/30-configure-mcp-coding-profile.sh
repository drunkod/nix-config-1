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
    --repo)
      [ "$#" -ge 2 ] || die "--repo requires a value"
      repo="$2"
      shift 2
      ;;
    --endpoint)
      [ "$#" -ge 2 ] || die "--endpoint requires a value"
      endpoint="$2"
      shift 2
      ;;
    --host)
      [ "$#" -ge 2 ] || die "--host requires a value"
      host="$2"
      shift 2
      ;;
    --port)
      [ "$#" -ge 2 ] || die "--port requires a value"
      port="$2"
      shift 2
      ;;
    --server-name)
      [ "$#" -ge 2 ] || die "--server-name requires a value"
      server_name="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
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
require_port "$port"
[[ "$server_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
  || die "invalid server name: $server_name"

cmd=(
  repo-harness mcp setup chatgpt
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
