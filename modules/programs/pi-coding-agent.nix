{
  flake.modules.homeManager."pi-coding-agent" =
    {
      lib,
      pkgs,
      ...
    }:
    let
      aiTools = import ../../ai-tools { inherit lib; };
    in
    {
      home = {
        packages = [
          pkgs.llm-agents.pi
        ];

        sessionVariables = {
          PI_SKIP_VERSION_CHECK = "1";
          PI_TELEMETRY = "0";
        };

        shellAliases = {
          pi-deep = "pi --model openai-codex/gpt-5.5 --thinking high";
          pi-json = "pi --mode json";
          pi-print = "pi --print";
          pi-quick = "pi --model openai-codex/gpt-5.3-codex-spark --thinking low";
          pi-read = "pi --tools read,grep,find,ls";
          pi-spark = "pi --model openai-codex/gpt-5.3-codex-spark --thinking high";
        };

        file = {
          ".pi/agent/skills".source = aiTools.piCodingAgent.skills;
          ".pi/agent/settings.json".text = builtins.toJSON {
            defaultProvider = "openai-codex";
            defaultModel = "gpt-5.3-codex-spark";
            defaultThinkingLevel = "high";
            enableInstallTelemetry = false;
            collapseChangelog = true;
            transport = "auto";

            compaction = {
              reserveTokens = 20000;
              keepRecentTokens = 50000;
            };

            retry.provider.maxRetryDelayMs = 60000;
          };
        };
      };
    };
}
