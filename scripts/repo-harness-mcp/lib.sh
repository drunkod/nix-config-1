#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[repo-harness-mcp] %s\n' "$*"
}

warn() {
  printf '[repo-harness-mcp] WARNING: %s\n' "$*" >&2
}

die() {
  printf '[repo-harness-mcp] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_directory() {
  [ -d "$1" ] || die "directory does not exist: $1"
}

require_loopback_host() {
  case "$1" in
    127.0.0.1|localhost|::1) ;;
    *) die "MCP host must be loopback, got: $1" ;;
  esac
}

require_https_mcp_endpoint() {
  case "$1" in
    https://*/mcp) ;;
    *) die "endpoint must be a public HTTPS URL ending in /mcp: $1" ;;
  esac
}

require_hostname() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ ]] \
    || die "invalid DNS hostname: $1"
  [[ "$1" != *..* ]] || die "invalid DNS hostname: $1"
}

require_uuid() {
  [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] \
    || die "invalid tunnel UUID: $1"
}

print_command() {
  printf '  '
  printf '%q ' "$@"
  printf '\n'
}

run_or_print() {
  local dry_run="$1"
  shift
  if [ "$dry_run" = "1" ]; then
    log "dry-run command:"
    print_command "$@"
  else
    "$@"
  fi
}

resolve_repo() {
  local value="${1:-${REPO_HARNESS_MCP_REPO:-$PWD}}"
  (
    cd "$value"
    pwd -P
  )
}
