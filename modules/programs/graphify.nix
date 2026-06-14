# All Graphify integration in one place.
#
# Source of truth: the external `graphify-vhdl-fresh` flake (offline, code-only,
# no-LLM graphify). This module only re-exposes it into the system config:
#
#   • flake apps    graphify-extract / -update / -query / -mcp / -test / -skill
#   • package       graphify-skill (the Cowork/Desktop Skill zip)
#   • dev shell     `nix develop .#graphify`
#   • home-manager  MCP server (auto-discovers graphify-out/graph.json) + zsh aliases
#
# To activate on a host, add `graphify` to its home-manager imports.
{ inputs, ... }:
{
  # ── flake outputs: apps, skill package, dev shell ───────────────────────────
  perSystem =
    { system, ... }:
    {
      apps = {
        graphify-extract = inputs.graphify-vhdl-fresh.apps.${system}.extract;
        graphify-update = inputs.graphify-vhdl-fresh.apps.${system}.update;
        graphify-query = inputs.graphify-vhdl-fresh.apps.${system}.query;
        graphify-mcp = inputs.graphify-vhdl-fresh.apps.${system}.mcp;
        graphify-test = inputs.graphify-vhdl-fresh.apps.${system}.test;
        graphify-skill = inputs.graphify-vhdl-fresh.apps.${system}.skill;
      };

      packages.graphify-skill = inputs.graphify-vhdl-fresh.packages.${system}.default;

      devShells.graphify = inputs.graphify-vhdl-fresh.devShells.${system}.default;
    };

  # ── home-manager: MCP server + zsh aliases ──────────────────────────────────
  flake.modules.homeManager.graphify =
    { lib, pkgs, ... }:
    let
      graphifyMcpApp =
        inputs.graphify-vhdl-fresh.apps.${pkgs.stdenv.hostPlatform.system}.mcp.program;
    in
    {
      imports = [ inputs.mcp-servers-nix.homeManagerModules.default ];

      programs.mcp = {
        enable = lib.mkDefault true;
        servers.graphify.command = lib.getExe (
          pkgs.writeShellScriptBin "graphify-mcp-wrapper" ''
            graph="''${GRAPHIFY_GRAPH_PATH:-}"

            if [ -z "$graph" ]; then
              dir="$PWD"
              while [ "$dir" != "/" ]; do
                candidate="$dir/graphify-out/graph.json"
                if [ -f "$candidate" ]; then
                  graph="$candidate"
                  break
                fi
                dir=$(dirname "$dir")
              done
            fi

            if [ -z "$graph" ]; then
              echo "graphify MCP: graph.json not found. Set GRAPHIFY_GRAPH_PATH or run from a project containing graphify-out/graph.json" >&2
              exit 1
            fi

            exec ${graphifyMcpApp} "$graph"
          ''
        );
      };

      # Aliases resolve the nix-config flake at runtime via graphify_flake_path.
      programs.zsh = {
        shellAliases = {
          graphify-extract = "nix run \"$(graphify_flake_path)\"#graphify-extract -- .";
          graphify-update = "nix run \"$(graphify_flake_path)\"#graphify-update -- .";
          graphify-query = "nix run \"$(graphify_flake_path)\"#graphify-query --";
          graphify-mcp = "nix run \"$(graphify_flake_path)\"#graphify-mcp --";
          graphify-shell = "nix develop \"$(graphify_flake_path)\"#graphify";
        };

        initContent = lib.mkOrder 600 ''
          graphify_flake_path() {
            local candidate
            for candidate in \
              "$HOME/nix-config" \
              "$HOME/.setup" \
              "$PWD"; do
              if [[ -f "$candidate/flake.nix" ]]; then
                printf '%s\n' "$candidate"
                return 0
              fi
            done

            echo "graphify: could not locate nix-config flake. Expected one of: ~/nix-config, ~/.setup, or current directory." >&2
            return 1
          }
        '';
      };
    };
}
