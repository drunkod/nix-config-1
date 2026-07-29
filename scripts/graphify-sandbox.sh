#!/usr/bin/env bash
set -euo pipefail

# Nix-free Graphify launcher for containers and Claude Code sandboxes.
#
# Requirements: bash, git, uv, and network access to the pinned source.
# For an offline sandbox, mount a Graphify source checkout and set:
#
#   GRAPHIFY_SOURCE_DIR=/workspace/vendor/graphify

readonly default_repository="https://github.com/safishamsi/graphify.git"
readonly default_revision="75922443866244d4bb6a266b8e085aa82b10dbe7"
readonly default_extras="mcp,watch,svg,sql,terraform"
readonly default_mcp_version="1.26.0"

runtime_dir="${GRAPHIFY_SANDBOX_STATE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/graphify-sandbox}"
venv_dir="$runtime_dir/.venv"
source_cache="$runtime_dir/src"
source_marker="$runtime_dir/source-id"
install_marker="$runtime_dir/install-id"
repository="${GRAPHIFY_SOURCE_REPOSITORY:-$default_repository}"
revision="${GRAPHIFY_SOURCE_REV:-$default_revision}"
extras="${GRAPHIFY_UV_EXTRAS-$default_extras}"
mcp_version="$default_mcp_version"

fail() {
  echo "graphify-sandbox: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

canonical_file() {
  local candidate="$1"
  local directory=""
  local basename=""

  if [ -d "$candidate" ]; then
    candidate="$candidate/graphify-out/graph.json"
  fi

  [ -f "$candidate" ] || return 1
  directory="$(dirname "$candidate")"
  basename="$(basename "$candidate")"
  printf '%s/%s\n' "$(cd "$directory" && pwd -P)" "$basename"
}

prepare_source() {
  local wanted_source_id=""
  local installed_source_id=""

  if [ -n "${GRAPHIFY_SOURCE_DIR:-}" ]; then
    [ -d "$GRAPHIFY_SOURCE_DIR" ] || fail "GRAPHIFY_SOURCE_DIR does not exist: $GRAPHIFY_SOURCE_DIR"
    source_dir="$(cd "$GRAPHIFY_SOURCE_DIR" && pwd -P)"
    [ -f "$source_dir/pyproject.toml" ] || fail "GRAPHIFY_SOURCE_DIR does not contain pyproject.toml: $source_dir"
    wanted_source_id="path:$source_dir@${GRAPHIFY_SOURCE_ID:-mounted}"
  else
    require_command git
    source_dir="$source_cache"
    wanted_source_id="git:$repository@$revision"

    if [ -f "$source_marker" ]; then
      IFS= read -r installed_source_id < "$source_marker" || true
    fi

    if [ "$installed_source_id" != "$wanted_source_id" ] || [ ! -d "$source_dir/.git" ] || [ ! -f "$source_dir/pyproject.toml" ]; then
      rm -rf "$source_dir"
      mkdir -p "$source_dir"
      git -C "$source_dir" init --quiet
      git -C "$source_dir" remote add origin "$repository"
      git -C "$source_dir" fetch --quiet --depth 1 origin "$revision"
      git -C "$source_dir" checkout --quiet --detach FETCH_HEAD
      [ -f "$source_dir/pyproject.toml" ] || fail "fetched Graphify source does not contain pyproject.toml"
      printf '%s\n' "$wanted_source_id" > "$source_marker"
    fi
  fi

  source_id="$wanted_source_id"
}

prepare_runtime() {
  local install_id=""
  local installed_id=""
  local install_spec=""
  local needs_install=0
  local wants_mcp=0

  require_command uv
  mkdir -p "$runtime_dir"
  prepare_source

  case ",$extras," in
    *,mcp,*|*,all,*)
      wants_mcp=1
      ;;
  esac

  install_id="$source_id|$extras|mcp==$mcp_version"
  if [ -f "$install_marker" ]; then
    IFS= read -r installed_id < "$install_marker" || true
  fi

  if [ "$installed_id" != "$install_id" ] || [ ! -x "$venv_dir/bin/graphify" ]; then
    needs_install=1
  fi

  if [ "$wants_mcp" -eq 1 ]; then
    if [ ! -x "$venv_dir/bin/graphify-mcp" ] || [ ! -x "$venv_dir/bin/python" ]; then
      needs_install=1
    elif ! "$venv_dir/bin/python" - "$mcp_version" <<'PY'
import sys
from importlib.metadata import version
from mcp.types import AnyUrl

raise SystemExit(0 if version("mcp") == sys.argv[1] else 1)
PY
    then
      needs_install=1
    fi
  fi

  if [ "$needs_install" -eq 1 ]; then
    rm -rf "$venv_dir"
    uv venv --quiet "$venv_dir"

    install_spec="$source_dir"
    if [ -n "$extras" ]; then
      install_spec="$source_dir[$extras]"
    fi

    echo "graphify-sandbox: installing pinned Graphify runtime" >&2
    if [ "$wants_mcp" -eq 1 ]; then
      uv pip install \
        --python "$venv_dir/bin/python" \
        "$install_spec" \
        "mcp==$mcp_version" \
        --quiet
    else
      uv pip install --python "$venv_dir/bin/python" "$install_spec" --quiet
    fi
    printf '%s\n' "$install_id" > "$install_marker"
  fi
}

usage() {
  cat <<'EOF'
Usage:
  graphify-sandbox.sh extract [project] [arguments...]
  graphify-sandbox.sh update [project] [arguments...]
  graphify-sandbox.sh query <query arguments...>
  graphify-sandbox.sh mcp <project-or-graph.json> [server arguments...]
  graphify-sandbox.sh graphify <Graphify CLI arguments...>

Environment:
  GRAPHIFY_SOURCE_DIR          Mounted/local Graphify source checkout
  GRAPHIFY_SOURCE_ID           Version token for a mounted source checkout
  GRAPHIFY_SOURCE_REPOSITORY   Source Git repository
  GRAPHIFY_SOURCE_REV          Pinned Git revision or tag
  GRAPHIFY_SANDBOX_STATE_DIR   Runtime/cache directory
  GRAPHIFY_UV_EXTRAS           Python extras; defaults to code/MCP essentials

The current Graphify revision requires the MCP Python SDK v1 API, so sandbox
runtimes pin mcp==1.26.0 and verify mcp.types.AnyUrl before reuse.
EOF
}

command_name="${1:-}"
if [ -z "$command_name" ] || [ "$command_name" = "--help" ] || [ "$command_name" = "-h" ]; then
  usage
  exit 0
fi
shift

prepare_runtime

case "$command_name" in
  extract)
    target="${1:-.}"
    if [ "$#" -gt 0 ]; then
      shift
    fi
    rm -f "$target/graphify-out/graph.json" "$target/graphify-out/manifest.json"
    exec "$venv_dir/bin/graphify" extract "$target" --no-cluster "$@"
    ;;
  update)
    target="${1:-.}"
    if [ "$#" -gt 0 ]; then
      shift
    fi
    exec "$venv_dir/bin/graphify" update "$target" --no-cluster "$@"
    ;;
  query)
    exec "$venv_dir/bin/graphify" query "$@"
    ;;
  mcp)
    [ "$#" -gt 0 ] || fail "mcp requires a project directory or graph.json path"
    graph="$(canonical_file "$1")" || fail "graph.json not found at: $1"
    shift
    [ -x "$venv_dir/bin/graphify-mcp" ] || fail "MCP executable is missing; include mcp in GRAPHIFY_UV_EXTRAS"
    echo "graphify-sandbox: selected explicit graph: $graph" >&2
    exec "$venv_dir/bin/graphify-mcp" "$graph" "$@"
    ;;
  graphify)
    exec "$venv_dir/bin/graphify" "$@"
    ;;
  *)
    usage >&2
    fail "unknown command: $command_name"
    ;;
esac
