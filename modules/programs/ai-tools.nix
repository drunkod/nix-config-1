{
  flake.modules.homeManager.codex =
    { config, pkgs, ... }:
    let
      settingsFormat = pkgs.formats.toml { };
    in
    {
      home = {
        packages = [
          pkgs.codex
          pkgs.jq
        ];

        shellAliases = {
          codex-deep = "codex --profile deep -c model_context_window=1000000 -c model_auto_compact_token_limit=850000";
          codex-nano = "codex --profile nano";
          codex-offline = "codex --profile offline";
          codex-quick = "codex --profile quick";
          codex-spark = "codex --profile spark";
          codex-unsafe = "codex --profile unsafe";
        };

        file = {
          ".codex/config.toml".source = settingsFormat.generate "codex-config.toml" {
            features = {
              apps = true;
              fast_mode = true;
              shell_snapshot = true;
              unified_exec = true;
              undo = true;
            };

            history = {
              persistence = "save-all";
              max_bytes = 104857600;
            };

            model = "gpt-5.5";
            model_auto_compact_token_limit = 240000;
            model_context_window = 272000;
            model_reasoning_effort = "medium";
            plan_mode_reasoning_effort = "medium";
            service_tier = "fast";
            personality = "pragmatic";
            approval_policy = "on-request";
            sandbox_mode = "danger-full-access";

            project_root_markers = [
              ".git"
              ".jj"
              ".hg"
              ".sl"
            ];

            profiles = {
              deep = {
                model = "gpt-5.4";
                model_reasoning_effort = "xhigh";
                model_verbosity = "high";
                plan_mode_reasoning_effort = "xhigh";
                web_search = "live";
              };

              nano = {
                model = "gpt-5.4-nano";
                model_reasoning_effort = "none";
                model_verbosity = "low";
                plan_mode_reasoning_effort = "low";
                service_tier = "flex";
                web_search = "disabled";
              };

              quick = {
                model = "gpt-5.3-codex-spark";
                model_reasoning_effort = "medium";
                model_reasoning_summary = "none";
                model_verbosity = "low";
                plan_mode_reasoning_effort = "medium";
                service_tier = "fast";
                web_search = "disabled";
              };

              spark = {
                model = "gpt-5.3-codex-spark";
                model_reasoning_effort = "medium";
                model_verbosity = "medium";
                plan_mode_reasoning_effort = "high";
                service_tier = "fast";
                web_search = "disabled";
              };

              offline = {
                sandbox_workspace_write.network_access = false;
                web_search = "disabled";
              };

              unsafe = {
                approval_policy = "on-request";
                sandbox_mode = "danger-full-access";
                shell_environment_policy.ignore_default_excludes = true;
              };
            };

            projects.${config.home.homeDirectory}.trust_level = "trusted";
          };

          ".codex/rules/read-only.md".text = ''
            # Read-only shell commands that should not require repeated approvals.
            prefix_rule(pattern = ["cat"], decision = "allow")
            prefix_rule(pattern = ["find"], decision = "allow")
            prefix_rule(pattern = ["git", "diff"], decision = "allow")
            prefix_rule(pattern = ["git", "log"], decision = "allow")
            prefix_rule(pattern = ["git", "show"], decision = "allow")
            prefix_rule(pattern = ["git", "status"], decision = "allow")
            prefix_rule(pattern = ["ls"], decision = "allow")
            prefix_rule(pattern = ["nix", "eval"], decision = "allow")
            prefix_rule(pattern = ["nix", "flake", "metadata"], decision = "allow")
            prefix_rule(pattern = ["nix", "flake", "show"], decision = "allow")
            prefix_rule(pattern = ["pwd"], decision = "allow")
            prefix_rule(pattern = ["rg"], decision = "allow")
            prefix_rule(pattern = ["sed", "-n"], decision = "allow")
          '';
        };
      };
    };

  flake.modules.homeManager."claude-code" =
    { pkgs, ... }:
    {
      home = {
        packages = [
          pkgs.master.claude-code
          pkgs.git
          pkgs.jq
          pkgs.jujutsu
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

        file.".claude/settings.json".text = builtins.toJSON {
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

          env.USE_BUILTIN_RIPGREP = "0";

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
              "Bash(ls:*)"
              "Bash(find:*)"
              "Bash(cat:*)"
              "Bash(head:*)"
              "Bash(tail:*)"
              "Bash(nix eval:*)"
              "Bash(nix flake show:*)"
              "Bash(nix flake metadata:*)"
              "Bash(rg:*)"
            ];

            ask = [
              "Bash(cp:*)"
              "Bash(curl:*)"
              "Bash(git add:*)"
              "Bash(git checkout:*)"
              "Bash(git commit:*)"
              "Bash(git pull:*)"
              "Bash(git push:*)"
              "Bash(git rebase:*)"
              "Bash(git reset:*)"
              "Bash(kill:*)"
              "Bash(mv:*)"
              "Bash(nix build:*)"
              "Bash(nix run:*)"
              "Bash(nix shell:*)"
              "Bash(rm:*)"
              "Bash(sudo:*)"
            ];

            deny = [
              "Bash(rm -rf /*)"
              "Bash(rm -rf /)"
            ];

            defaultMode = "default";
          };
        };
      };
    };

  flake.modules.homeManager."pi-coding-agent" =
    { pkgs, ... }:
    {
      home = {
        packages = [
          pkgs.pi-coding-agent
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

        file.".pi/agent/settings.json".text = builtins.toJSON {
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
}
