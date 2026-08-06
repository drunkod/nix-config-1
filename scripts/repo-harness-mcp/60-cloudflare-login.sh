#!/usr/bin/env bash
set -euo pipefail
# External interactive operation: authenticates cloudflared with Cloudflare.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

dry_run=0
[ "${1:-}" = "--dry-run" ] && dry_run=1
require_command cloudflared
run_or_print "$dry_run" cloudflared tunnel login
