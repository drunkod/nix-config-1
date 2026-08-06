#!/usr/bin/env bash
set -euo pipefail
# Source: repo-harness coding tutorial, health and OAuth discovery smoke tests.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

host="${MCP_HOST:-127.0.0.1}"
port="${MCP_PORT:-8765}"
require_command curl
require_loopback_host "$host"

curl --fail --silent --show-error --max-time 5 "http://${host}:${port}/health"
printf '\n'
curl --fail --silent --show-error --max-time 5 \
  "http://${host}:${port}/.well-known/oauth-protected-resource/mcp" >/dev/null
log "local health and OAuth discovery checks passed"
