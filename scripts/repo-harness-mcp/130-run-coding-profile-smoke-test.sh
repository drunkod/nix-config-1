#!/usr/bin/env bash
set -euo pipefail
# Local smoke only. A visible ChatGPT Called tool event remains required for invocation evidence.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

repo=""
host="${MCP_HOST:-127.0.0.1}"
port="${MCP_PORT:-8765}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      [ "$#" -ge 2 ] || die "--repo requires a value"
      repo="$2"
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
    -h|--help)
      echo "usage: $0 [--repo PATH] [--host 127.0.0.1] [--port 8765]"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

repo="$(resolve_repo "$repo")"
require_command jq
require_command repo-harness
require_loopback_host "$host"
require_port "$port"

config_file="$HOME/.repo-harness/mcp.local.json"
[ -f "$config_file" ] || die "MCP config is missing"
jq -e '.scope == "user" and .profile == "coding" and .coding.enabled == true' \
  "$config_file" >/dev/null || die "coding profile is not enabled"

MCP_HOST="$host" MCP_PORT="$port" \
  "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/50-check-local-mcp-health.sh"
repo-harness mcp doctor --repo "$repo" --live --json \
  | jq -e '.status == "mcp_ready" or .stage == "mcp_ready" or .mcp_ready == true' >/dev/null \
  || die "live doctor did not report mcp_ready"

log "local coding-profile smoke passed"
log "next: refresh the ChatGPT app schema and verify a real open_workspace/read tool call"
