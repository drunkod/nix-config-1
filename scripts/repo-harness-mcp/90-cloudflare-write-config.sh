#!/usr/bin/env bash
set -euo pipefail
# Local operation: writes a runtime cloudflared config outside the Nix store.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

tunnel_id="${CLOUDFLARED_TUNNEL_ID:-}"
hostname="${CLOUDFLARED_HOSTNAME:-}"
credentials_file="${CLOUDFLARED_CREDENTIALS_FILE:-}"
config_file="${CLOUDFLARED_CONFIG_FILE:-$HOME/.config/cloudflared/repo-harness-mcp.yml}"
local_origin="${REPO_HARNESS_MCP_LOCAL_ORIGIN:-http://127.0.0.1:8765}"
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tunnel-id)
      [ "$#" -ge 2 ] || die "--tunnel-id requires a value"
      tunnel_id="$2"
      shift 2
      ;;
    --hostname)
      [ "$#" -ge 2 ] || die "--hostname requires a value"
      hostname="$2"
      shift 2
      ;;
    --credentials-file)
      [ "$#" -ge 2 ] || die "--credentials-file requires a value"
      credentials_file="$2"
      shift 2
      ;;
    --config-file)
      [ "$#" -ge 2 ] || die "--config-file requires a value"
      config_file="$2"
      shift 2
      ;;
    --local-origin)
      [ "$#" -ge 2 ] || die "--local-origin requires a value"
      local_origin="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      echo "usage: $0 --tunnel-id UUID --hostname HOST --credentials-file PATH [--config-file PATH] [--local-origin http://127.0.0.1:8765] [--dry-run]"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_command jq
require_uuid "$tunnel_id"
require_hostname "$hostname"
require_absolute_path "$credentials_file"
require_outside_nix_store "$credentials_file"
require_absolute_path "$config_file"
require_outside_nix_store "$config_file"

origin_port=""
case "$local_origin" in
  http://127.0.0.1:*) origin_port="${local_origin#http://127.0.0.1:}" ;;
  http://localhost:*) origin_port="${local_origin#http://localhost:}" ;;
  http://\[::1\]:*) origin_port="${local_origin#http://\[::1\]:}" ;;
  *) die "local origin must use loopback HTTP: $local_origin" ;;
esac
require_port "$origin_port"
[ -f "$credentials_file" ] || die "credentials file not found: $credentials_file"

hostname_yaml="$(printf '%s' "$hostname" | jq -Rs .)"
credentials_yaml="$(printf '%s' "$credentials_file" | jq -Rs .)"
local_origin_yaml="$(printf '%s' "$local_origin" | jq -Rs .)"

render() {
  cat <<YAML
tunnel: ${tunnel_id}
credentials-file: ${credentials_yaml}

ingress:
  - hostname: ${hostname_yaml}
    service: ${local_origin_yaml}
  - service: http_status:404
YAML
}

if [ "$dry_run" -eq 1 ]; then
  render
  exit 0
fi

umask 077
mkdir -p "$(dirname "$config_file")"
tmp="$(mktemp "${config_file}.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
render >"$tmp"
mv "$tmp" "$config_file"
trap - EXIT
chmod 600 "$config_file"
log "wrote runtime tunnel config: $config_file"
