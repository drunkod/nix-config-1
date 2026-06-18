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
    in
    {
      imports = [
        inputs.mcp-servers-nix.homeManagerModules.default
      ];

      programs.mcp = {
        enable = lib.mkDefault true;
        servers = {
          graphify = {
            command = lib.getExe (
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

          slintcn = {
            command = lib.getExe (
              pkgs.writeShellScriptBin "slintcn-mcp-wrapper" ''
                export PATH="${pkgs.nodejs}/bin:$PATH"
                exec npx -y -p slintcn slintcn-mcp
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
        };
      };
    };
}
