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

  mkApp = name: body: {
    type = "app";
    program = "${pkgs.writeShellScriptBin name (bootstrap + "\n" + body)}/bin/${name}";
  };

  graphifyWrapper = pkgs.writeShellScriptBin "graphify" (bootstrap + ''
    exec "$VIRTUAL_ENV/bin/graphify" "$@"
  '');

  graphifyMcpWrapper = pkgs.writeShellScriptBin "graphify-mcp" (bootstrap + ''
    exec "$VIRTUAL_ENV/bin/graphify-mcp" "$@"
  '');

  graphifySkillWrapper = pkgs.writeShellScriptBin "graphify-skill" (bootstrap + ''
    exec "$VIRTUAL_ENV/bin/graphify" install "$@"
  '');

  cleanOutputs = target: ''
    rm -f "${target}/graphify-out/graph.json" "${target}/graphify-out/manifest.json"
  '';
in
{
  apps = rec {
    graphify = mkApp "graphify" ''
      exec "$VIRTUAL_ENV/bin/graphify" "$@"
    '';

    extract = mkApp "graphify-extract" ''
      target="''${1:-.}"
      ${cleanOutputs "$target"}
      exec "$VIRTUAL_ENV/bin/graphify" extract "$target" --no-cluster
    '';

    update = mkApp "graphify-update" ''
      target="''${1:-.}"
      ${cleanOutputs "$target"}
      exec "$VIRTUAL_ENV/bin/graphify" extract "$target" --no-cluster
    '';

    query = mkApp "graphify-query" ''
      exec "$VIRTUAL_ENV/bin/graphify" query "$@"
    '';

    mcp = mkApp "graphify-mcp" ''
      graph="''${1:-graphify-out/graph.json}"
      if [ ! -f "$graph" ]; then
        echo "ERROR: $graph not found — run 'graphify extract <project>' first" >&2
        exit 1
      fi
      exec "$VIRTUAL_ENV/bin/graphify-mcp" "$graph"
    '';

    test = mkApp "graphify-test" ''
      exec "$VIRTUAL_ENV/bin/graphify" "$@"
    '';

    skill = mkApp "graphify-skill" ''
      exec "$VIRTUAL_ENV/bin/graphify" install "$@"
    '';

    default = graphify;
  };

  packages = {
    graphify = graphifyWrapper;
    graphify-mcp = graphifyMcpWrapper;
    skill = graphifySkillWrapper;
    default = graphifyWrapper;
  };

  devShells.default = pkgs.mkShell {
    packages = toolchain ++ [
      graphifyWrapper
      graphifyMcpWrapper
      graphifySkillWrapper
    ];

    shellHook = ''
      echo "Graphify CLI is available as: graphify"
      echo "Run: graphify --help"
    '';
  };

  checks.skill = pkgs.runCommand "graphify-wrapper-check" { } ''
    test -x ${graphifyWrapper}/bin/graphify
    test -x ${graphifyMcpWrapper}/bin/graphify-mcp
    mkdir -p "$out"
  '';
}
