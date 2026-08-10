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

require_port() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]] \
    && [ "$value" -ge 1 ] \
    && [ "$value" -le 65535 ] \
    || die "invalid TCP port: $value"
}

format_url_host() {
  case "$1" in
    ::1) printf '[::1]' ;;
    *) printf '%s' "$1" ;;
  esac
}

require_https_mcp_endpoint() {
  case "$1" in
    https://*/mcp) ;;
    *) die "endpoint must be a public HTTPS URL ending in /mcp: $1" ;;
  esac
}

require_hostname() {
  local value="$1"
  local label
  local -a labels=()

  [ -n "$value" ] || die "DNS hostname must not be empty"
  [ "${#value}" -le 253 ] || die "DNS hostname is too long: $value"
  [[ "$value" =~ ^[A-Za-z0-9.-]+$ ]] || die "invalid DNS hostname: $value"
  [[ "$value" != .* && "$value" != *. && "$value" != *..* ]] \
    || die "invalid DNS hostname: $value"

  IFS='.' read -r -a labels <<< "$value"
  for label in "${labels[@]}"; do
    [[ "$label" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] \
      || die "invalid DNS hostname label in: $value"
  done
}

require_uuid() {
  [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] \
    || die "invalid tunnel UUID: $1"
}

require_absolute_path() {
  case "$1" in
    /*) ;;
    *) die "path must be absolute: $1" ;;
  esac
}

require_outside_nix_store() {
  case "$1" in
    /nix/store|/nix/store/*) die "runtime path must remain outside /nix/store: $1" ;;
    *) ;;
  esac
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
