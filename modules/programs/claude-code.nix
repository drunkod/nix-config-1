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

      commonClaudeSettings = {
        theme = "dark";
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
        };
        permissions = permissions;
      };

      mkExtraProfile = dir: extraSettings:
        let
          extraAgents = lib.mapAttrs' (
            name: text:
            lib.nameValuePair "${dir}/agents/${name}.md" { inherit text; }
          ) aiTools.claudeCode.agents;
          extraCommands = lib.mapAttrs' (
            name: text:
            lib.nameValuePair "${dir}/commands/${name}.md" { inherit text; }
          ) aiTools.claudeCode.commands;
        in
        {
          "${dir}/CLAUDE.md".source = aiTools.base;
          "${dir}/settings.json".text = builtins.toJSON (
            commonClaudeSettings
            // {
              "$schema" = "https://json.schemastore.org/claude-code-settings.json";
            }
            // extraSettings
          );
          "${dir}/.mcp.json".source = config.xdg.configFile."mcp/mcp.json".source;
          "${dir}/skills".source = aiTools.claudeCode.skills;
        }
        // extraAgents
        // extraCommands;

      claudeFiles =
        mkExtraProfile ".claude-work" { }
        // mkExtraProfile ".claude-api" {
          model = "qwen3.5:9b";
          env = {
            ANTHROPIC_API_KEY = "";
            ANTHROPIC_AUTH_TOKEN = "ollama";
            ANTHROPIC_BASE_URL = "http://localhost:11434";
            ANTHROPIC_MODEL = "qwen3.5:9b";
          };
        }
        // mkExtraProfile ".claude-freemodel" {
          model = "claude-sonnet-4.6";
          env = {
            ANTHROPIC_BASE_URL = "https://cc.freemodel.dev";
          };
        };
    in
    {
      imports = [ (import ./claude.nix).flake.modules.homeManager.claude ];

      # Declare the secret here, in the module output (only if sops is enabled)
      sops.secrets = lib.mkIf (config.services.sops.enable or false) {
        "freemodel/apikey" = {
          sopsFile = ../../secrets/default.yaml;
          path = "${config.home.homeDirectory}/.config/sops-nix/freemodel-apikey";
        };
      };

      xdg.dataFile."icons/claude.ico".source = claudeCodeDir + "/assets/claude.ico";

      programs.claude-code = {
        enable = true;
        package = pkgs.llm-agents.claude-code;
        enableMcpIntegration = true;

        context = aiTools.base;
        skills = aiTools.claudeCode.skills;
        agents = aiTools.claudeCode.agents;
        commands = aiTools.claudeCode.commands;

        settings = commonClaudeSettings;
      };

      home = {
        packages = with pkgs; [
          git
          jq
          jujutsu
          nano
        ];

        shellAliases = {
          claude-work = "CLAUDE_CONFIG_DIR=$HOME/.claude-work claude";
          claude-api = "CLAUDE_CONFIG_DIR=$HOME/.claude-api claude";
          # Reference config.sops.secrets here — resolved after module merging
          claude-freemodel = "ANTHROPIC_API_KEY=$(cat ${config.sops.secrets."freemodel/apikey".path}) CLAUDE_CONFIG_DIR=$HOME/.claude-freemodel claude";
        };

        file = claudeFiles;
      };
    };
}
