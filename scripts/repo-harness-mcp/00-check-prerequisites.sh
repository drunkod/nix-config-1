#!/usr/bin/env bash
set -euo pipefail
# Source: repo-harness ChatGPT MCP coding tutorial, prerequisites and security boundary.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

repo="$(resolve_repo "${1:-}")"
require_directory "$repo"

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) die "unsupported operating system: $(uname -s)" ;;
esac

case "$(uname -m)" in
  arm64|aarch64|x86_64) ;;
  *) warn "untested architecture: $(uname -m)" ;;
esac

for cmd in repo-harness cloudflared curl git jq; do
  require_command "$cmd"
done

require_loopback_host "${MCP_HOST:-127.0.0.1}"

git -C "$repo" rev-parse --show-toplevel >/dev/null
log "repository: $repo"
log "OS/architecture: $(uname -s)/$(uname -m)"
log "repo-harness: $(repo-harness --version | head -n 1)"
log "cloudflared: $(cloudflared --version | head -n 1)"
log "prerequisites are available"
