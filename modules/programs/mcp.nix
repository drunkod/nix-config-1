{ inputs, ... }:

{
  # The graphify MCP server lives in modules/programs/graphify.nix.
  flake.modules.homeManager.mcp =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        inputs.mcp-servers-nix.homeManagerModules.default
      ];

      programs.mcp = {
        enable = lib.mkDefault true;
        servers = {
          slintcn = {
            command = lib.getExe (pkgs.writeShellScriptBin "slintcn-mcp-wrapper" ''
              export PATH="${pkgs.nodejs}/bin:$PATH"
              exec npx -y -p slintcn slintcn-mcp
            '');
          };
        };
      };
    };
}
