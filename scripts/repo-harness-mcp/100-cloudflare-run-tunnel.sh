#!/usr/bin/env bash
set -euo pipefail
# Foreground debug runner. The durable m1-min process is managed by launchd.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

config_file="${CLOUDFLARED_CONFIG_FILE:-$HOME/.config/cloudflared/repo-harness-mcp.yml}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config-file)
      [ "$#" -ge 2 ] || die "--config-file requires a value"
      config_file="$2"
      shift 2
      ;;
    -h|--help)
      echo "usage: $0 [--config-file PATH]"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_command cloudflared
require_absolute_path "$config_file"
require_outside_nix_store "$config_file"
[ -f "$config_file" ] || die "tunnel config not found: $config_file"
exec cloudflared tunnel --config "$config_file" run
