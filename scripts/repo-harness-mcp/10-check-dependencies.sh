#!/usr/bin/env bash
set -euo pipefail
# This script verifies dependencies only. repo-harness is managed by modules/programs/repo-harness.nix.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

missing=0
for cmd in bash repo-harness cloudflared curl git jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'missing: %s\n' "$cmd" >&2
    missing=1
  else
    printf 'found: %-12s %s\n' "$cmd" "$(command -v "$cmd")"
  fi
done

[ "$missing" -eq 0 ] || die "install missing dependencies through Nix; this script never installs them"
log "dependency check passed"
