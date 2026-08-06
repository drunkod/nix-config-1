#!/usr/bin/env bash
set -euo pipefail
# Source: repo-harness coding tutorial, repository adoption prerequisite.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

repo=""
apply=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --apply) apply=1; shift ;;
    --dry-run) apply=0; shift ;;
    -h|--help)
      echo "usage: $0 [--repo PATH] [--dry-run|--apply]"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

repo="$(resolve_repo "$repo")"
require_command repo-harness
require_command git
require_directory "$repo"

git -C "$repo" rev-parse --show-toplevel >/dev/null

if [ "$apply" -eq 0 ]; then
  log "previewing repo-harness initialization for $repo"
  (cd "$repo" && repo-harness init --dry-run)
  log "no files were changed; rerun with --apply after review"
else
  log "initializing or refreshing repo-harness in $repo"
  (cd "$repo" && repo-harness init)
  (cd "$repo" && repo-harness init --dry-run >/dev/null)
  log "repository initialization completed and a repeat dry-run succeeds"
fi
