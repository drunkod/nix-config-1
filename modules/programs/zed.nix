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
        theme = "One Dark";
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
