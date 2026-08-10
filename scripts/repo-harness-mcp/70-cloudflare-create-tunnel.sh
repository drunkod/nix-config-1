#!/usr/bin/env bash
set -euo pipefail
# External operation: creates a named Cloudflare Tunnel, but never DNS.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

name="${CLOUDFLARED_TUNNEL_NAME:-repo-harness-coding}"
dry_run=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)
      [ "$#" -ge 2 ] || die "--name requires a value"
      name="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      echo "usage: $0 [--name NAME] [--dry-run]"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_command cloudflared
require_command jq
[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || die "invalid tunnel name: $name"

existing="$(cloudflared tunnel list --output json 2>/dev/null \
  | jq -r --arg name "$name" '.[] | select(.name == $name) | .id' \
  | head -n 1 || true)"
if [ -n "$existing" ]; then
  log "tunnel already exists: $name ($existing)"
  exit 0
fi

run_or_print "$dry_run" cloudflared tunnel create "$name"
