{ inputs, ... }:

{
  flake.modules.homeManager.mcp =
    {
      lib,
      pkgs,
      ...
    }:
    let
      graphifyMcpApp = inputs.self.apps.${pkgs.system}.graphify-mcp.program;
      graphifyMcpSetGraph = pkgs.writeShellScriptBin "graphify-mcp-set-graph" ''
        target="''${1:-$PWD}"
        state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
        state_dir="$state_home/graphify"
        state_file="$state_dir/mcp-graph-path"

        if [ -d "$target" ]; then
          candidate="$target/graphify-out/graph.json"
        else
          candidate="$target"
        fi

        if [ ! -f "$candidate" ]; then
          echo "graphify-mcp-set-graph: graph.json not found at $candidate" >&2
          echo "graphify-mcp-set-graph: run graphify-extract for the project first" >&2
          exit 1
        fi

        candidate_dir=$(dirname "$candidate")
        candidate_base=$(basename "$candidate")
        graph="$(cd "$candidate_dir" && pwd -P)/$candidate_base"

        mkdir -p "$state_dir"
        printf '%s\n' "$graph" > "$state_file"
        echo "$graph"
      '';
    in
    {
      imports = [
        inputs.mcp-servers-nix.homeManagerModules.default
      ];

      home.packages = [
        graphifyMcpSetGraph
      ];

      programs.mcp = {
        enable = lib.mkDefault true;
        servers = {
          graphify = {
            command = lib.getExe (
              pkgs.writeShellScriptBin "graphify-mcp-wrapper" ''
                state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
                state_file="$state_home/graphify/mcp-graph-path"
                graph=""

                use_graph() {
                  candidate="$1"

                  if [ -d "$candidate" ]; then
                    candidate="$candidate/graphify-out/graph.json"
                  fi

                  if [ -f "$candidate" ]; then
                    graph="$candidate"
                    return 0
                  fi

                  return 1
                }

                if [ -n "''${GRAPHIFY_GRAPH_PATH:-}" ]; then
                  use_graph "$GRAPHIFY_GRAPH_PATH"
                fi

                if [ -z "$graph" ] && [ -f "$state_file" ]; then
                  read -r candidate < "$state_file"
                  use_graph "$candidate"
                fi

                if [ -z "$graph" ] && [ -n "''${GRAPHIFY_PROJECT_ROOT:-}" ]; then
                  use_graph "$GRAPHIFY_PROJECT_ROOT"
                fi

                if [ -z "$graph" ]; then
                  dir="$PWD"
                  while [ "$dir" != "/" ]; do
                    if use_graph "$dir"; then
                      break
                    fi
                    dir=$(dirname "$dir")
                  done
                fi

                if [ -z "$graph" ]; then
                  for candidate in \
                    "$HOME/nix-config" \
                    "$HOME/.setup" \
                    "$HOME/Documents/work/nix-config" \
                    "$HOME/.graphify/global-graph.json"
                  do
                    if use_graph "$candidate"; then
                      break
                    fi
                  done
                fi

                if [ -z "$graph" ]; then
                  echo "graphify MCP: graph.json not found. Set GRAPHIFY_GRAPH_PATH, run graphify-mcp-set-graph, or run from a project containing graphify-out/graph.json" >&2
                  exit 1
                fi

                echo "graphify MCP: using graph $graph" >&2
                exec ${graphifyMcpApp} "$graph"
              ''
            );
          };

          slintcn = {
            command = lib.getExe (
              pkgs.writeShellScriptBin "slintcn-mcp-wrapper" ''
                export PATH="${pkgs.nodejs}/bin:$PATH"
                exec npx -y -p slintcn slintcn-mcp
              ''
            );
          };

          jazz-docs = {
            command = lib.getExe (
              pkgs.writeShellScriptBin "jazz-docs-mcp-wrapper" ''
                export PATH="${pkgs.nodejs_22}/bin:$PATH"
                exec npx -y jazz-tools@alpha mcp
              ''
            );
          };

          chrome-devtools = {
            command = lib.getExe (
              pkgs.writeShellScriptBin "chrome-devtools-mcp-wrapper" ''
                export PATH="${pkgs.nodejs}/bin:$PATH"
                exec npx -y chrome-devtools-mcp@latest --browser-url=http://127.0.0.1:9222
              ''
            );
          };

          codewebchat = {
            command = lib.getExe (
              pkgs.writeShellScriptBin "codewebchat-mcp-wrapper" ''
                set -euo pipefail

                export PATH="${pkgs.nodejs_22}/bin:$PATH"

                repo="/Users/test/Documents/work/CodeWebChat"
                cd "$repo"

                if [ ! -s .jazz/app-id ]; then
                  echo "codewebchat MCP: missing .jazz/app-id. Run scripts/jazz-server.sh once first." >&2
                  exit 1
                fi

                if [ ! -f apps/mcp-server/dist/index.js ]; then
                  echo "codewebchat MCP: missing apps/mcp-server/dist/index.js. Run scripts/build.sh first." >&2
                  exit 1
                fi

                export CWC_ALLOW_OUTSIDE_NIX=1
                export CWC_TRANSPORT="jazz"
                export JAZZ_EXTERNAL_SERVER="1"
                export JAZZ_SERVER_URL="ws://localhost:1625"
                export JAZZ_APP_ID="$(cat .jazz/app-id)"
                export JAZZ_ADMIN_SECRET="cwc-rt-admin"
                export JAZZ_BACKEND_SECRET="cwc-rt-backend"

                exec scripts/run-jazz-external.sh
              ''
            );
            env = { };
          };
        };
      };
    };
}
