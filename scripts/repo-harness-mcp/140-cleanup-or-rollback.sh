#!/usr/bin/env bash
set -euo pipefail
# Safe cleanup: never deletes Cloudflare tunnels, DNS, certificates, or credentials.
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

repo=""
revoke_write=0
remove_generated_config=0
apply=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --revoke-write) revoke_write=1; shift ;;
    --remove-generated-cloudflared-config) remove_generated_config=1; shift ;;
    --apply) apply=1; shift ;;
    --dry-run) apply=0; shift ;;
    -h|--help)
      echo "usage: $0 [--repo PATH] [--revoke-write] [--remove-generated-cloudflared-config] [--dry-run|--apply]"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

repo="$(resolve_repo "$repo")"
config_file="${CLOUDFLARED_CONFIG_FILE:-$HOME/.config/cloudflared/repo-harness-mcp.yml}"

for label in org.nix-community.home.repo-harness-mcp org.nix-community.home.cloudflared-mcp-tunnel; do
  if [ "$(uname -s)" = "Darwin" ]; then
    if [ "$apply" -eq 1 ]; then
      /bin/launchctl bootout "gui/$UID/$label" 2>/dev/null || true
    else
      log "dry-run: launchctl bootout gui/$UID/$label"
    fi
  fi
done

if [ "$revoke_write" -eq 1 ]; then
  if [ "$apply" -eq 1 ]; then
    repo-harness mcp access set --repo "$repo" --mode read_only --json
  else
    log "dry-run: revoke coding access for $repo"
  fi
fi

if [ "$remove_generated_config" -eq 1 ]; then
  if [ "$apply" -eq 1 ]; then
    rm -f "$config_file"
    log "removed generated runtime config: $config_file"
  else
    log "dry-run: remove $config_file"
  fi
fi

log "Cloudflare tunnel, DNS records, login certificate, and credentials were not deleted"
