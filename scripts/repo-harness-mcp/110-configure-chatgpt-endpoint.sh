#!/usr/bin/env bash
set -euo pipefail
# Re-runs supported repo-harness setup when the stable public endpoint changes.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$script_dir/30-configure-mcp-coding-profile.sh" "$@"
