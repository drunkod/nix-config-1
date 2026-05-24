{
  flake.modules.homeManager."claude-code" =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      hooks = map (file: import file { inherit config lib pkgs; }) [
        ./hooks/notification.nix
        ./hooks/post-tool-audit.nix
        ./hooks/post-tool-validate.nix
        ./hooks/pre-compact.nix
        ./hooks/pre-tool-audit.nix
        ./hooks/pre-tool-use.nix
        ./hooks/session-end.nix
        ./hooks/session-start.nix
        ./hooks/subagent-stop.nix
      ];

      mergedHooks = lib.zipAttrsWith (_: values: lib.concatLists values) hooks;
    in
    {
      home = {
        packages = [
          pkgs.master.claude-code
          pkgs.git
          pkgs.jq
          pkgs.jujutsu
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          pkgs.terminal-notifier
        ];

        sessionVariables = {
          ANTHROPIC_API_KEY = "";
          ANTHROPIC_AUTH_TOKEN = "ollama";
          ANTHROPIC_BASE_URL = "http://localhost:11434";
          ANTHROPIC_MODEL = "qwen3.5:9b";
          CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
          CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
          DISABLE_TELEMETRY = "1";
        };

        file = {
          ".claude/settings.json".text = builtins.toJSON {
            theme = "dark";
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
              USE_BUILTIN_RIPGREP = "0";
            };

            hooks = mergedHooks;

            permissions = {
              allow = [
                "Glob(*)"
                "Grep(*)"
                "LS(*)"
                "Read(*)"
                "Search(*)"
                "Task(*)"
                "TodoWrite(*)"
                "Bash(git status)"
                "Bash(git log:*)"
                "Bash(git diff:*)"
                "Bash(git show:*)"
                "Bash(git branch:*)"
                "Bash(ls:*)"
                "Bash(find:*)"
                "Bash(cat:*)"
                "Bash(head:*)"
                "Bash(tail:*)"
                "Bash(nix eval:*)"
                "Bash(nix flake show:*)"
                "Bash(nix flake metadata:*)"
                "Bash(nix search:*)"
                "Bash(nix log:*)"
                "Bash(nix path-info:*)"
                "Bash(rg:*)"
                "Bash(grep:*)"
                "Bash(mkdir:*)"
              ];

              ask = [
                "Bash(cp:*)"
                "Bash(curl:*)"
                "Bash(git add:*)"
                "Bash(git checkout:*)"
                "Bash(git commit:*)"
                "Bash(git merge:*)"
                "Bash(git pull:*)"
                "Bash(git push:*)"
                "Bash(git rebase:*)"
                "Bash(git reset:*)"
                "Bash(git restore:*)"
                "Bash(git stash:*)"
                "Bash(git switch:*)"
                "Bash(kill:*)"
                "Bash(mv:*)"
                "Bash(nix build:*)"
                "Bash(nix run:*)"
                "Bash(nix shell:*)"
                "Bash(rm:*)"
                "Bash(scp:*)"
                "Bash(ssh:*)"
                "Bash(sudo:*)"
                "Bash(wget:*)"
              ];

              deny = [
                "Bash(rm -rf /*)"
                "Bash(rm -rf /)"
              ];

              defaultMode = "default";
            };
          };

          ".local/share/icons/claude.ico".source = ./assets/claude.ico;
        };
      };
    };
}
