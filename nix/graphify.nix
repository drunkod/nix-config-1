{ pkgs, graphify-src }:
let
  lib = pkgs.lib;
  python = pkgs.python311;

  toolchain = [
    python
    pkgs.uv
    pkgs.git
    pkgs.ripgrep
  ];

  binPath = lib.makeBinPath toolchain;
  defaultExtras = "mcp,watch,svg,sql,terraform";

  # Runtime bootstrap for the Python package. The Graphify source is pinned by
  # flake.lock, while Python wheels are managed by uv in a user-writable venv.
  #
  # The default extras cover code extraction, MCP, watching, SVG export, SQL,
  # and Terraform. Opt into heavier semantic/document providers explicitly:
  #
  #   GRAPHIFY_UV_EXTRAS=all graphify --help
  #   GRAPHIFY_UV_EXTRAS=mcp,pdf,office graphify --help
  #   GRAPHIFY_UV_EXTRAS= graphify --help
  #
  bootstrap = ''
    export PATH="${binPath}:$PATH"
    set -euo pipefail

    state_dir="''${GRAPHIFY_NIX_STATE_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/graphify-nix}"
    venv_dir="$state_dir/.venv"
    src_dir="$state_dir/src"
    marker="$state_dir/install-id"
    extras="''${GRAPHIFY_UV_EXTRAS-${defaultExtras}}"
    install_id="${graphify-src}|$extras"
    installed_id=""
    needs_install=0

    mkdir -p "$state_dir"

    if [ -f "$marker" ]; then
      IFS= read -r installed_id < "$marker" || true
    fi

    if [ "$installed_id" != "$install_id" ] || [ ! -x "$venv_dir/bin/graphify" ]; then
      needs_install=1
    fi

    case ",$extras," in
      *,mcp,*)
        if [ ! -x "$venv_dir/bin/graphify-mcp" ]; then
          needs_install=1
        fi
        ;;
    esac

    if [ "$needs_install" -eq 1 ]; then
      rm -rf "$venv_dir" "$src_dir"
      uv venv --quiet "$venv_dir"

      mkdir -p "$src_dir"
      cp -R "${graphify-src}/." "$src_dir/"
      chmod -R u+w "$src_dir"

      install_spec="$src_dir"
      if [ -n "$extras" ]; then
        install_spec="$src_dir[$extras]"
      fi

      echo "→ Installing Graphify into $venv_dir ..." >&2
      uv pip install --python "$venv_dir/bin/python" "$install_spec" --quiet
      printf '%s\n' "$install_id" > "$marker"
    fi

    # shellcheck disable=SC1091
    . "$venv_dir/bin/activate"
  '';

  resetExtractOutputs = target: ''
    rm -f "${target}/graphify-out/graph.json" "${target}/graphify-out/manifest.json"
  '';

  mkGraphifyBin = name: body:
    pkgs.writeShellScriptBin name (bootstrap + "\n" + body);

  mkApp = name: bin: {
    type = "app";
    program = "${bin}/bin/${name}";
  };

  graphifyMcpState = ''
    state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
    state_dir="$state_home/graphify"
    state_file="''${GRAPHIFY_MCP_STATE_FILE:-$state_dir/mcp-graph-path}"
  '';

  graphifyResolveCandidate = ''
    graphify_resolve_candidate() {
      local candidate="''${1:-}"
      local candidate_dir=""
      local candidate_base=""

      [ -n "$candidate" ] || return 1

      if [ -d "$candidate" ]; then
        candidate="$candidate/graphify-out/graph.json"
      fi

      [ -f "$candidate" ] || return 1

      candidate_dir="$(dirname "$candidate")"
      candidate_base="$(basename "$candidate")"
      graph="$(cd "$candidate_dir" && pwd -P)/$candidate_base"
    }
  '';

  # Automatic discovery is deliberately project-scoped. It never reads the
  # saved global graph and never falls back to unrelated repositories.
  graphifyFindProjectGraph = ''
    graphify_find_project_graph() {
      local dir=""

      graph=""
      graph_source=""

      if [ -n "''${GRAPHIFY_GRAPH_PATH:-}" ]; then
        if ! graphify_resolve_candidate "$GRAPHIFY_GRAPH_PATH"; then
          echo "graphify MCP: GRAPHIFY_GRAPH_PATH is not a readable graph: $GRAPHIFY_GRAPH_PATH" >&2
          return 2
        fi
        graph_source="GRAPHIFY_GRAPH_PATH"
        return 0
      fi

      if [ -n "''${GRAPHIFY_PROJECT_ROOT:-}" ]; then
        if ! graphify_resolve_candidate "$GRAPHIFY_PROJECT_ROOT"; then
          echo "graphify MCP: GRAPHIFY_PROJECT_ROOT does not contain graphify-out/graph.json: $GRAPHIFY_PROJECT_ROOT" >&2
          return 2
        fi
        graph_source="GRAPHIFY_PROJECT_ROOT"
        return 0
      fi

      dir="$(pwd -P)"
      while true; do
        if graphify_resolve_candidate "$dir"; then
          graph_source="workspace search"
          return 0
        fi

        if [ "$dir" = "/" ]; then
          break
        fi

        dir="$(dirname "$dir")"
      done

      return 1
    }
  '';

  graphifyFindSavedGraph = ''
    graphify_find_saved_graph() {
      local candidate=""

      graph=""
      graph_source="saved state"

      if [ ! -f "$state_file" ]; then
        echo "graphify MCP: no graph is saved; run graphify-mcp-set-graph <project-or-graph>" >&2
        return 1
      fi

      IFS= read -r candidate < "$state_file" || true
      if ! graphify_resolve_candidate "$candidate"; then
        echo "graphify MCP: saved graph no longer exists: $candidate" >&2
        return 2
      fi
    }
  '';

  graphifyWrapper = mkGraphifyBin "graphify" ''
    exec "$VIRTUAL_ENV/bin/graphify" "$@"
  '';

  graphifyExtractWrapper = mkGraphifyBin "graphify-extract" ''
    target="''${1:-.}"
    if [ "$#" -gt 0 ]; then
      shift
    fi
    ${resetExtractOutputs "$target"}
    exec "$VIRTUAL_ENV/bin/graphify" extract "$target" --no-cluster "$@"
  '';

  # Update must preserve graph.json and manifest.json because they are the
  # incremental input. The previous wrapper deleted them before every update.
  graphifyUpdateWrapper = mkGraphifyBin "graphify-update" ''
    target="''${1:-.}"
    if [ "$#" -gt 0 ]; then
      shift
    fi
    exec "$VIRTUAL_ENV/bin/graphify" update "$target" --no-cluster "$@"
  '';

  graphifyQueryWrapper = mkGraphifyBin "graphify-query" ''
    exec "$VIRTUAL_ENV/bin/graphify" query "$@"
  '';

  graphifyMcpWrapper = mkGraphifyBin "graphify-mcp" ''
    if [ ! -x "$VIRTUAL_ENV/bin/graphify-mcp" ]; then
      echo "graphify MCP: graphify-mcp is not installed; include the mcp extra in GRAPHIFY_UV_EXTRAS" >&2
      exit 1
    fi
    exec "$VIRTUAL_ENV/bin/graphify-mcp" "$@"
  '';

  graphifyMcpFindGraphWrapper = pkgs.writeShellScriptBin "graphify-mcp-find-graph" ''
    set -euo pipefail
    ${graphifyResolveCandidate}
    ${graphifyFindProjectGraph}

    status=0
    graphify_find_project_graph || status=$?

    if [ "$status" -eq 0 ]; then
      echo "graphify MCP: selected graph via $graph_source: $graph" >&2
      printf '%s\n' "$graph"
      exit 0
    fi

    if [ "$status" -eq 1 ]; then
      echo "graphify MCP: no project graph found. Set GRAPHIFY_GRAPH_PATH, set GRAPHIFY_PROJECT_ROOT, or start the client inside a project containing graphify-out/graph.json" >&2
    fi
    exit "$status"
  '';

  graphifyMcpSetGraphWrapper = pkgs.writeShellScriptBin "graphify-mcp-set-graph" ''
    set -euo pipefail
    ${graphifyMcpState}
    ${graphifyResolveCandidate}
    ${graphifyFindSavedGraph}

    case "''${1:-}" in
      --clear)
        rm -f "$state_file"
        echo "graphify MCP: cleared saved graph" >&2
        exit 0
        ;;
      --show)
        status=0
        graphify_find_saved_graph || status=$?
        if [ "$status" -eq 0 ]; then
          printf '%s\n' "$graph"
        fi
        exit "$status"
        ;;
      --help|-h)
        cat <<'EOF'
Usage:
  graphify-mcp-set-graph <project-directory-or-graph.json>
  graphify-mcp-set-graph --show
  graphify-mcp-set-graph --clear

Saved state is used only by graphify-mcp-saved. It is never consulted by
project-scoped graphify-mcp-auto.
EOF
        exit 0
        ;;
    esac

    target="''${1:-$PWD}"
    graph=""
    if ! graphify_resolve_candidate "$target"; then
      if [ -d "$target" ]; then
        candidate="$target/graphify-out/graph.json"
      else
        candidate="$target"
      fi
      echo "graphify-mcp-set-graph: graph.json not found at $candidate" >&2
      echo "graphify-mcp-set-graph: run graphify-extract for the project first" >&2
      exit 1
    fi

    mkdir -p "$(dirname "$state_file")"
    temporary_state="$(mktemp "$state_file.XXXXXX")"
    trap 'rm -f "$temporary_state"' EXIT
    printf '%s\n' "$graph" > "$temporary_state"
    mv "$temporary_state" "$state_file"
    trap - EXIT

    printf '%s\n' "$graph"
  '';

  graphifyMcpRunWrapper = pkgs.writeShellScriptBin "graphify-mcp-run" ''
    set -euo pipefail
    ${graphifyResolveCandidate}

    if [ "$#" -eq 0 ]; then
      echo "Usage: graphify-mcp-run <project-directory-or-graph.json> [graphify-mcp arguments...]" >&2
      exit 2
    fi

    candidate="$1"
    shift

    graph=""
    if ! graphify_resolve_candidate "$candidate"; then
      echo "graphify MCP: graph.json not found at $candidate" >&2
      echo "graphify MCP: run graphify-extract for the project first" >&2
      exit 1
    fi

    echo "graphify MCP: selected explicit graph: $graph" >&2
    exec ${graphifyMcpWrapper}/bin/graphify-mcp "$graph" "$@"
  '';

  graphifyMcpAutoWrapper = pkgs.writeShellScriptBin "graphify-mcp-auto" ''
    set -euo pipefail
    graph="$(${graphifyMcpFindGraphWrapper}/bin/graphify-mcp-find-graph)"
    exec ${graphifyMcpWrapper}/bin/graphify-mcp "$graph" "$@"
  '';

  graphifyMcpSavedWrapper = pkgs.writeShellScriptBin "graphify-mcp-saved" ''
    set -euo pipefail
    ${graphifyMcpState}
    ${graphifyResolveCandidate}
    ${graphifyFindSavedGraph}

    status=0
    graphify_find_saved_graph || status=$?
    if [ "$status" -eq 0 ]; then
      echo "graphify MCP: selected graph via $graph_source: $graph" >&2
      exec ${graphifyMcpWrapper}/bin/graphify-mcp "$graph" "$@"
    fi
    exit "$status"
  '';

  graphifyTestWrapper = mkGraphifyBin "graphify-test" ''
    exec "$VIRTUAL_ENV/bin/graphify" "$@"
  '';

  graphifySkillWrapper = mkGraphifyBin "graphify-skill" ''
    exec "$VIRTUAL_ENV/bin/graphify" install "$@"
  '';
in
{
  apps = rec {
    graphify = mkApp "graphify" graphifyWrapper;
    extract = mkApp "graphify-extract" graphifyExtractWrapper;
    update = mkApp "graphify-update" graphifyUpdateWrapper;
    query = mkApp "graphify-query" graphifyQueryWrapper;
    mcp = mkApp "graphify-mcp" graphifyMcpWrapper;
    mcp-find-graph = mkApp "graphify-mcp-find-graph" graphifyMcpFindGraphWrapper;
    mcp-set-graph = mkApp "graphify-mcp-set-graph" graphifyMcpSetGraphWrapper;
    mcp-run = mkApp "graphify-mcp-run" graphifyMcpRunWrapper;
    mcp-auto = mkApp "graphify-mcp-auto" graphifyMcpAutoWrapper;
    mcp-saved = mkApp "graphify-mcp-saved" graphifyMcpSavedWrapper;
    test = mkApp "graphify-test" graphifyTestWrapper;
    skill = mkApp "graphify-skill" graphifySkillWrapper;

    default = graphify;
  };

  packages = {
    graphify = graphifyWrapper;
    graphify-extract = graphifyExtractWrapper;
    graphify-update = graphifyUpdateWrapper;
    graphify-query = graphifyQueryWrapper;
    graphify-mcp = graphifyMcpWrapper;
    graphify-mcp-find-graph = graphifyMcpFindGraphWrapper;
    graphify-mcp-set-graph = graphifyMcpSetGraphWrapper;
    graphify-mcp-run = graphifyMcpRunWrapper;
    graphify-mcp-auto = graphifyMcpAutoWrapper;
    graphify-mcp-saved = graphifyMcpSavedWrapper;
    graphify-test = graphifyTestWrapper;
    graphify-skill = graphifySkillWrapper;
    skill = graphifySkillWrapper;
    default = graphifyWrapper;
  };

  devShells.default = pkgs.mkShell {
    packages = toolchain ++ [
      graphifyWrapper
      graphifyExtractWrapper
      graphifyUpdateWrapper
      graphifyQueryWrapper
      graphifyMcpWrapper
      graphifyMcpFindGraphWrapper
      graphifyMcpSetGraphWrapper
      graphifyMcpRunWrapper
      graphifyMcpAutoWrapper
      graphifyMcpSavedWrapper
      graphifyTestWrapper
      graphifySkillWrapper
    ];

    shellHook = ''
      echo "Graphify CLI commands are available:"
      echo "  graphify --help"
      echo "  graphify-extract ."
      echo "  graphify-update ."
      echo "  graphify-query \"question\" --graph graphify-out/graph.json"
      echo "  graphify-mcp-auto"
      echo "  graphify-mcp-run /absolute/project/graphify-out/graph.json"
      echo "  graphify-mcp-set-graph ."
      echo "  graphify-mcp-saved"
    '';
  };

  checks.skill = pkgs.runCommand "graphify-wrapper-check" { } ''
    test -x ${graphifyWrapper}/bin/graphify
    test -x ${graphifyExtractWrapper}/bin/graphify-extract
    test -x ${graphifyUpdateWrapper}/bin/graphify-update
    test -x ${graphifyQueryWrapper}/bin/graphify-query
    test -x ${graphifyMcpWrapper}/bin/graphify-mcp
    test -x ${graphifyMcpFindGraphWrapper}/bin/graphify-mcp-find-graph
    test -x ${graphifyMcpSetGraphWrapper}/bin/graphify-mcp-set-graph
    test -x ${graphifyMcpRunWrapper}/bin/graphify-mcp-run
    test -x ${graphifyMcpAutoWrapper}/bin/graphify-mcp-auto
    test -x ${graphifyMcpSavedWrapper}/bin/graphify-mcp-saved

    if grep -q 'rm -f .*graphify-out/graph.json' ${graphifyUpdateWrapper}/bin/graphify-update; then
      echo "graphify-update must preserve the existing graph" >&2
      exit 1
    fi

    export HOME="$TMPDIR/home"
    export XDG_STATE_HOME="$TMPDIR/state"

    saved_project="$TMPDIR/saved-project"
    workspace="$TMPDIR/workspace"
    mkdir -p "$saved_project/graphify-out" "$workspace/graphify-out" "$workspace/nested/path"
    touch "$saved_project/graphify-out/graph.json"
    touch "$workspace/graphify-out/graph.json"

    saved="$(${graphifyMcpSetGraphWrapper}/bin/graphify-mcp-set-graph "$saved_project")"
    test "$saved" = "$saved_project/graphify-out/graph.json"
    test "$(${graphifyMcpSetGraphWrapper}/bin/graphify-mcp-set-graph --show)" = "$saved"

    cd "$workspace/nested/path"
    found="$(${graphifyMcpFindGraphWrapper}/bin/graphify-mcp-find-graph)"
    test "$found" = "$workspace/graphify-out/graph.json"

    rm "$workspace/graphify-out/graph.json"
    if ${graphifyMcpFindGraphWrapper}/bin/graphify-mcp-find-graph >/dev/null 2>&1; then
      echo "project discovery incorrectly used saved global state" >&2
      exit 1
    fi
    touch "$workspace/graphify-out/graph.json"

    found="$(GRAPHIFY_GRAPH_PATH="$saved_project/graphify-out/graph.json" ${graphifyMcpFindGraphWrapper}/bin/graphify-mcp-find-graph)"
    test "$found" = "$saved_project/graphify-out/graph.json"

    found="$(GRAPHIFY_PROJECT_ROOT="$saved_project" ${graphifyMcpFindGraphWrapper}/bin/graphify-mcp-find-graph)"
    test "$found" = "$saved_project/graphify-out/graph.json"

    if GRAPHIFY_GRAPH_PATH="$TMPDIR/missing.json" ${graphifyMcpFindGraphWrapper}/bin/graphify-mcp-find-graph >/dev/null 2>&1; then
      echo "invalid GRAPHIFY_GRAPH_PATH must fail closed" >&2
      exit 1
    fi

    ${graphifyMcpSetGraphWrapper}/bin/graphify-mcp-set-graph --clear
    test ! -e "$XDG_STATE_HOME/graphify/mcp-graph-path"
    if ${graphifyMcpSetGraphWrapper}/bin/graphify-mcp-set-graph --show >/dev/null 2>&1; then
      echo "showing a cleared saved graph must fail" >&2
      exit 1
    fi

    mkdir -p "$out"
  '';
}
