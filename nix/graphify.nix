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

  # Runtime bootstrap for the Python package. The Graphify source is pinned by
  # flake.lock, while Python wheels are managed by uv in a user-writable venv.
  #
  # Defaults install useful CLI extras but intentionally avoid the upstream
  # "all" extra because it includes dm/video dependencies that are fragile or
  # very heavy on macOS. Override when needed, for example:
  #
  #   GRAPHIFY_UV_EXTRAS=all graphify --help
  #   GRAPHIFY_UV_EXTRAS= graphify --help
  #
  bootstrap = ''
    export PATH="${binPath}:$PATH"
    set -euo pipefail

    state_dir="''${GRAPHIFY_NIX_STATE_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/graphify-nix}"
    venv_dir="$state_dir/.venv"
    src_dir="$state_dir/src"
    marker="$state_dir/source-path"

    mkdir -p "$state_dir"

    if [ ! -d "$venv_dir" ]; then
      uv venv --quiet "$venv_dir"
    fi

    # shellcheck disable=SC1091
    . "$venv_dir/bin/activate"

    current_source="${graphify-src}"
    installed_source=""
    if [ -f "$marker" ]; then
      installed_source="$(cat "$marker")"
    fi

    if [ "$installed_source" != "$current_source" ] || [ ! -x "$venv_dir/bin/graphify" ]; then
      rm -rf "$src_dir"
      mkdir -p "$src_dir"
      cp -R "${graphify-src}/." "$src_dir/"
      chmod -R u+w "$src_dir"

      extras="''${GRAPHIFY_UV_EXTRAS-mcp,pdf,office,watch,svg,sql,terraform,openai,anthropic,gemini,bedrock,ollama,kimi,chinese,neo4j,falkordb,postgres}"
      install_spec="$src_dir"
      if [ -n "$extras" ]; then
        install_spec="$src_dir[$extras]"
      fi

      echo "→ Installing Graphify into $venv_dir ..." >&2
      uv pip install "$install_spec" --quiet
      printf '%s\n' "$current_source" > "$marker"
    fi
  '';

  cleanOutputs = target: ''
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
      local candidate_dir
      local candidate_base

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

  graphifyFindGraph = ''
    graphify_find_graph() {
      local candidate
      local dir
      local fallbacks
      local -a fallback_candidates

      graph=""

      if [ -n "''${GRAPHIFY_GRAPH_PATH:-}" ]; then
        graphify_resolve_candidate "$GRAPHIFY_GRAPH_PATH" || true
      fi

      if [ -z "$graph" ] && [ -f "$state_file" ]; then
        IFS= read -r candidate < "$state_file" || true
        graphify_resolve_candidate "$candidate" || true
      fi

      if [ -z "$graph" ] && [ -n "''${GRAPHIFY_PROJECT_ROOT:-}" ]; then
        graphify_resolve_candidate "$GRAPHIFY_PROJECT_ROOT" || true
      fi

      if [ -z "$graph" ]; then
        dir="$PWD"
        while true; do
          if graphify_resolve_candidate "$dir"; then
            break
          fi

          if [ "$dir" = "/" ]; then
            break
          fi

          dir="$(dirname "$dir")"
        done
      fi

      if [ -z "$graph" ]; then
        fallbacks="''${GRAPHIFY_MCP_FALLBACKS:-$HOME/nix-config:$HOME/.setup:$HOME/Documents/work/nix-config:$HOME/.graphify/global-graph.json}"
        IFS=':' read -r -a fallback_candidates <<< "$fallbacks"

        for candidate in "''${fallback_candidates[@]}"; do
          if graphify_resolve_candidate "$candidate"; then
            break
          fi
        done
      fi

      [ -n "$graph" ]
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
    ${cleanOutputs "$target"}
    exec "$VIRTUAL_ENV/bin/graphify" extract "$target" --no-cluster "$@"
  '';

  graphifyUpdateWrapper = mkGraphifyBin "graphify-update" ''
    target="''${1:-.}"
    if [ "$#" -gt 0 ]; then
      shift
    fi
    ${cleanOutputs "$target"}
    exec "$VIRTUAL_ENV/bin/graphify" update "$target" --no-cluster "$@"
  '';

  graphifyQueryWrapper = mkGraphifyBin "graphify-query" ''
    exec "$VIRTUAL_ENV/bin/graphify" query "$@"
  '';

  graphifyMcpWrapper = mkGraphifyBin "graphify-mcp" ''
    exec "$VIRTUAL_ENV/bin/graphify-mcp" "$@"
  '';

  graphifyMcpFindGraphWrapper = pkgs.writeShellScriptBin "graphify-mcp-find-graph" ''
    set -euo pipefail
    ${graphifyMcpState}
    ${graphifyResolveCandidate}
    ${graphifyFindGraph}

    if ! graphify_find_graph; then
      echo "graphify MCP: graph.json not found. Set GRAPHIFY_GRAPH_PATH, run graphify-mcp-set-graph, or run from a project containing graphify-out/graph.json" >&2
      exit 1
    fi

    printf '%s\n' "$graph"
  '';

  graphifyMcpSetGraphWrapper = pkgs.writeShellScriptBin "graphify-mcp-set-graph" ''
    set -euo pipefail
    ${graphifyMcpState}
    ${graphifyResolveCandidate}

    case "''${1:-}" in
      --clear)
        rm -f "$state_file"
        echo "graphify MCP: cleared saved graph" >&2
        exit 0
        ;;
      --show)
        if [ ! -f "$state_file" ]; then
          echo "graphify MCP: no graph is currently saved" >&2
          exit 1
        fi

        IFS= read -r candidate < "$state_file"
        graph=""
        if ! graphify_resolve_candidate "$candidate"; then
          echo "graphify MCP: saved graph no longer exists: $candidate" >&2
          exit 1
        fi

        printf '%s\n' "$graph"
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

  graphifyMcpRunWrapper = mkGraphifyBin "graphify-mcp-run" ''
    ${graphifyResolveCandidate}

    candidate="''${1:-graphify-out/graph.json}"
    if [ "$#" -gt 0 ]; then
      shift
    fi

    graph=""
    if ! graphify_resolve_candidate "$candidate"; then
      echo "graphify MCP: graph.json not found at $candidate" >&2
      echo "graphify MCP: run 'graphify extract <project>' first" >&2
      exit 1
    fi

    exec "$VIRTUAL_ENV/bin/graphify-mcp" "$graph" "$@"
  '';

  graphifyMcpAutoWrapper = mkGraphifyBin "graphify-mcp-auto" ''
    graph="$(${graphifyMcpFindGraphWrapper}/bin/graphify-mcp-find-graph)"
    echo "graphify MCP: using graph $graph" >&2
    exec "$VIRTUAL_ENV/bin/graphify-mcp" "$graph" "$@"
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
      echo "  graphify-mcp-set-graph ."
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

    export HOME="$TMPDIR/home"
    export XDG_STATE_HOME="$TMPDIR/state"
    project="$TMPDIR/project"
    mkdir -p "$project/graphify-out"
    touch "$project/graphify-out/graph.json"

    selected="$(${graphifyMcpSetGraphWrapper}/bin/graphify-mcp-set-graph "$project")"
    test "$selected" = "$project/graphify-out/graph.json"
    test "$(${graphifyMcpSetGraphWrapper}/bin/graphify-mcp-set-graph --show)" = "$selected"
    test "$(${graphifyMcpFindGraphWrapper}/bin/graphify-mcp-find-graph)" = "$selected"

    ${graphifyMcpSetGraphWrapper}/bin/graphify-mcp-set-graph --clear
    test ! -e "$XDG_STATE_HOME/graphify/mcp-graph-path"

    mkdir -p "$out"
  '';
}
