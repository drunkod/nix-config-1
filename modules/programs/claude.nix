{
  flake.modules.homeManager.claude =
    {
      pkgs,
      lib,
      config,
      ...
    }:
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
    };
}
