{
  flake.modules.homeManager.zed =
    { config, lib, pkgs, ... }:
    let
      settingsFormat = pkgs.formats.json { };
    in
    {
      xdg.configFile."zed/settings.json".source = settingsFormat.generate "zed-settings.json" ({
        telemetry = {
          diagnostics = false;
          metrics = false;
        };
        ui_font_size = 16;
        buffer_font_size = 14;
        # Follow macOS light/dark appearance automatically
        theme = {
          dark = "One Dark";
          light = "One Light";
          mode = "system";
        };
        # Auto-approve agent tool actions (allow mode)
        agent = {
          tool_permissions = {
            default = "allow";
          };
        };
      } // lib.optionalAttrs (config.programs.mcp.enable or false) {
        context_servers = lib.mapAttrs (name: server: {
            command = server.command;
            args = server.args or [];
            env = server.env or {};
          }
        ) config.programs.mcp.servers;
      });
    };
}
