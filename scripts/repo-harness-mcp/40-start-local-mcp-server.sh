#!/usr/bin/env bash
set -euo pipefail
# Source: repo-harness coding tutorial, loopback HTTP server.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

repo=""
host="${MCP_HOST:-127.0.0.1}"
port="${MCP_PORT:-8765}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --host) host="$2"; shift 2 ;;
    --port) port="$2"; shift 2 ;;
    -h|--help)
      echo "usage: $0 [--repo PATH] [--host 127.0.0.1] [--port 8765]"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

repo="$(resolve_repo "$repo")"
require_command repo-harness
require_loopback_host "$host"
[ -f "$HOME/.repo-harness/mcp.local.json" ] || die "run 30-configure-mcp-coding-profile.sh first"

exec repo-harness mcp serve \
  --repo "$repo" \
  --transport http \
  --host "$host" \
  --port "$port" \
  --profile coding \
  --auth oauth
