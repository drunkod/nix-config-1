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
      mkClaudeProfile =
        dir: settings:
        {
          "${dir}/CLAUDE.md".source = aiTools.base;
          "${dir}/settings.json".text = mkClaudeSettings settings;
          "${dir}/skills".source = aiTools.claudeCode.skills;
        };
      claudeFiles =
        mkClaudeFiles "agents" aiTools.claudeCode.agents
        // mkClaudeFiles "commands" aiTools.claudeCode.commands
        // mkClaudeProfile ".claude" { }
        // mkClaudeProfile ".claude-work" { }
        // mkClaudeProfile ".claude-api" {
          model = "qwen3.5:9b";
          env = {
            ANTHROPIC_API_KEY = "";
            ANTHROPIC_AUTH_TOKEN = "ollama";
            ANTHROPIC_BASE_URL = "http://localhost:11434";
            ANTHROPIC_MODEL = "qwen3.5:9b";
          };
        }
        // mkClaudeProfile ".claude-freemodel" {
          model = "claude-sonnet-4.6";
          env = {
            ANTHROPIC_API_KEY = "";
            ANTHROPIC_BASE_URL = "https://cc.freemodel.dev";
          };
        };
    in
    {
      imports = [ (import ./claude.nix).flake.modules.homeManager.claude ];

      # Declare the secret here, in the module output
      sops.secrets."freemodel/apikey" = {
        sopsFile = ../../secrets/default.yaml;
        path = "${config.home.homeDirectory}/.config/sops-nix/freemodel-apikey";
      };

      xdg.dataFile."icons/claude.ico".source = claudeCodeDir + "/assets/claude.ico";

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