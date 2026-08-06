#!/usr/bin/env bash
set -euo pipefail
# Source: repo-harness coding tutorial, live readiness chain.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

repo=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    -h|--help) echo "usage: $0 [--repo PATH]"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

repo="$(resolve_repo "$repo")"
require_command repo-harness
exec repo-harness mcp doctor --repo "$repo" --live --json
