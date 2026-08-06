#!/usr/bin/env bash
set -euo pipefail
# External operation: creates the DNS route separately and fails closed on conflicts.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

tunnel="${CLOUDFLARED_TUNNEL_ID:-}"
hostname="${CLOUDFLARED_HOSTNAME:-}"
dry_run=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --tunnel) tunnel="$2"; shift 2 ;;
    --hostname) hostname="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) echo "usage: $0 --tunnel UUID_OR_NAME --hostname mcp.example.com [--dry-run]"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$tunnel" ] || die "--tunnel is required"
[ -n "$hostname" ] || die "--hostname is required"
require_hostname "$hostname"
require_command cloudflared

log "this command does not overwrite an existing conflicting DNS record"
run_or_print "$dry_run" cloudflared tunnel route dns "$tunnel" "$hostname"
