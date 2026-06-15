{
  flake.modules.homeManager.claude =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      claudeDesktopConfig = {
        mcpServers = lib.mapAttrs (
          _: server:
          lib.filterAttrs (_: v: v != null && v != [ ] && v != { }) {
            command = server.command;
            args = server.args or [ ];
            env = server.env or { };
          }
        ) config.programs.mcp.servers;
      };
    in
    {
      home = {
        packages = lib.mkIf (!(config.programs.claude-code.enable or false)) [
          pkgs.llm-agents.claude-code
        ];
        sessionVariables = {
          CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
          CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
          DISABLE_TELEMETRY = "1";
        };

        shellAliases = {
          claude-default = "claude --model default";
          claude-opus = "claude --model opus";
          claude-sonnet = "claude --model sonnet";
        };
      };

      home.file = lib.optionalAttrs (pkgs.stdenv.isDarwin && (config.programs.mcp.enable or false)) {
        "Library/Application Support/Claude/claude_desktop_config.json".text =
          builtins.toJSON claudeDesktopConfig;
      };
    };
}
