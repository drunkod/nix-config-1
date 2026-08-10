#!/usr/bin/env bash
set -euo pipefail
# External interactive operation: authenticates cloudflared with Cloudflare.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

dry_run=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      echo "usage: $0 [--dry-run]"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_command cloudflared
run_or_print "$dry_run" cloudflared tunnel login
