{ inputs, ... }:

{
  flake.modules.homeManager.mcp =
    {
      lib,
      pkgs,
      ...
    }:
    let
      graphifyPackages = inputs.self.packages.${pkgs.system};

      mkMcpScript = name: body:
        lib.getExe (
          pkgs.writeShellScriptBin name ''
            set -euo pipefail
            ${body}
          ''
        );

      mkNpxMcp =
        {
          name,
          arguments,
          nodejs ? pkgs.nodejs,
        }:
        mkMcpScript name ''
          exec ${nodejs}/bin/npx ${arguments}
        '';
    in
    {
      imports = [
        inputs.mcp-servers-nix.homeManagerModules.default
      ];

      home.packages = [
        graphifyPackages.graphify-mcp-set-graph
      ];

      programs.mcp = {
        enable = lib.mkDefault true;
        servers = {
          graphify = {
            command = lib.getExe graphifyPackages.graphify-mcp-auto;
          };

          slintcn = {
            command = mkNpxMcp {
              name = "slintcn-mcp-wrapper";
              arguments = "-y -p slintcn slintcn-mcp";
            };
          };

          jazz-docs = {
            command = mkNpxMcp {
              name = "jazz-docs-mcp-wrapper";
              nodejs = pkgs.nodejs_22;
              arguments = "-y jazz-tools@alpha mcp";
            };
          };

          chrome-devtools = {
            command = mkNpxMcp {
              name = "chrome-devtools-mcp-wrapper";
              arguments = "-y chrome-devtools-mcp@latest --browser-url=http://127.0.0.1:9222";
            };
          };

          codewebchat = {
            command = mkMcpScript "codewebchat-mcp-wrapper" ''
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
            '';
            env = { };
          };
        };
      };
    };
}
