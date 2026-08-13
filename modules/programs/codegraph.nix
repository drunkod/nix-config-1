{
  flake.modules.homeManager.codegraph =
    { lib, pkgs, ... }:
    let
      codegraph = pkgs.llm-agents.codegraph;
    in
    {
      home.packages = [ codegraph ];

      programs.mcp.servers.codegraph = {
        command = lib.getExe codegraph;
        args = [
          "serve"
          "--mcp"
        ];
      };
    };
}
