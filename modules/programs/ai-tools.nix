{
  flake.modules.homeManager."claude-code" =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      aiTools = import ../../ai-tools { inherit lib; };
      claudeCodeDir = ../../ai-tools/claude-code;
      hookDir = claudeCodeDir + "/hooks";
      hookFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (builtins.readDir hookDir);
      hookSets = lib.mapAttrsToList (name: _: import (hookDir + "/${name}") { inherit config lib pkgs; }) hookFiles;
      hooks = lib.zipAttrsWith (_: values: lib.concatLists values) hookSets;
      permissions = import (claudeCodeDir + "/permissions.nix") {
        inherit config lib;
        profile = "standard";
      };
      mkClaudeSettings =
        {
          model ? "default",
          env ? { },
        }:
        builtins.toJSON {
          theme = "dark";
          inherit model;
          hooks = hooks;
          verbose = true;
          includeCoAuthoredBy = false;
          gitAttribution = false;

          attribution = {
            commit = "";
            pr = "";
          };

          statusLine = {
            type = "command";
            command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')] $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
            padding = 0;
          };

          env = {
            EDITOR = "nano";
            USE_BUILTIN_RIPGREP = "0";
            VISUAL = "nano";
          }
          // env;

          inherit permissions;
        };
      mkClaudeFiles =
        prefix: files:
        lib.mapAttrs' (
          name: text:
          lib.nameValuePair ".claude/${prefix}/${name}.md" { inherit text; }
        ) files;
      claudeFiles =
        mkClaudeFiles "agents" aiTools.claudeCode.agents
        // mkClaudeFiles "commands" aiTools.claudeCode.commands
        // {
          ".claude/CLAUDE.md".source = aiTools.base;
          ".claude/settings.json".text = mkClaudeSettings { };
          ".claude/skills".source = aiTools.claudeCode.skills;
          ".claide-work/CLAUDE.md".source = aiTools.base;
          ".claide-work/settings.json".text = mkClaudeSettings { };
          ".claide-work/skills".source = aiTools.claudeCode.skills;
          ".claude-api/CLAUDE.md".source = aiTools.base;
          ".claude-api/settings.json".text = mkClaudeSettings {
            model = "qwen3.5:9b";
            env = {
              ANTHROPIC_API_KEY = "";
              ANTHROPIC_AUTH_TOKEN = "ollama";
              ANTHROPIC_BASE_URL = "http://localhost:11434";
              ANTHROPIC_MODEL = "qwen3.5:9b";
            };
          };
          ".claude-api/skills".source = aiTools.claudeCode.skills;
        };
    in
    {
      xdg.dataFile."icons/claude.ico".source = claudeCodeDir + "/assets/claude.ico";

      home = {
        packages = [
          pkgs.llm-agents.claude-code
          pkgs.git
          pkgs.jq
          pkgs.jujutsu
          pkgs.nano
        ];

        sessionVariables = {
          CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
          CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
          DISABLE_TELEMETRY = "1";
        };

        shellAliases = {
          claide-work = "CLAUDE_CONFIG_DIR=$HOME/.claide-work claude";
          claude-api = "CLAUDE_CONFIG_DIR=$HOME/.claude-api claude";
          claude-default = "claude --model default";
          claude-opus = "claude --model opus";
          claude-sonnet = "claude --model sonnet";
        };

        file = claudeFiles;
      };
    };
}
