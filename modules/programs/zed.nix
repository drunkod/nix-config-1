{
  flake.modules.homeManager.zed =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      settingsFormat = pkgs.formats.json { };
      aiTools = import ../../ai-tools { inherit lib; };
    in
    {
      # Nix language server + formatter, installed declaratively so Zed never
      # depends on them being on PATH (Zed launched from Dock/Finder on macOS
      # does not inherit the shell PATH).
      home.packages = [
        pkgs.nil
        pkgs.nixfmt-rfc-style
      ];

      home.file.".agents/skills".source = aiTools.skillsDir;

      xdg.configFile."zed/settings.json".source = settingsFormat.generate "zed-settings.json" (
        {
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
          # Point the Nix extension at the nil binary by absolute store path,
          # and let nil format via nixfmt.
          lsp = {
            nil = {
              binary.path = lib.getExe pkgs.nil;
              settings.formatting.command = [ (lib.getExe pkgs.nixfmt-rfc-style) ];
            };
          };
          languages.Nix.language_servers = [ "nil" ];
          # Auto-approve agent tool actions (allow mode)
          agent = {
            tool_permissions = {
              default = "allow";
            };
          };
        }
        // lib.optionalAttrs (config.programs.mcp.enable or false) {
          context_servers = lib.mapAttrs (name: server: {
            command = server.command;
            args = server.args or [ ];
            env = server.env or { };
          }) config.programs.mcp.servers;
        }
      );
    };
}
