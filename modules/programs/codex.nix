{
  flake.modules.homeManager.codex =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      aiTools = import ../../ai-tools { inherit lib; };
      settingsFormat = pkgs.formats.toml { };
      codexNotify = pkgs.writeShellApplication {
        name = "codex-notify";
        runtimeInputs = [
          pkgs.jq
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.libnotify ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.terminal-notifier ];
        text = ''
          payload="$1"
          eventType="$(printf '%s' "$payload" | jq -r '.type // ""')"
          [ "$eventType" = "agent-turn-complete" ] || exit 0

          message="$(printf '%s' "$payload" | jq -r '.["last-assistant-message"] // "Turn complete"')"
          summary="$(printf '%s' "$message" | cut -c1-180)"

          ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
            ${lib.getExe pkgs.terminal-notifier} -title "Codex" -message "$summary" -group "codex-turn" >/dev/null 2>&1
          ''}
          ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            ${lib.getExe pkgs.libnotify}/bin/notify-send "Codex" "$summary" >/dev/null 2>&1
          ''}
        '';
      };
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
              multi_agent = true;
              prevent_idle_sleep = true;
              skill_mcp_dependency_install = true;
              shell_snapshot = true;
              unified_exec = true;
              undo = true;
            };

            agents = {
              max_threads = 6;
              max_depth = 1;
              job_max_runtime_seconds = 3600;
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
            notify = [ (lib.getExe codexNotify) ];
            personality = "pragmatic";
            approval_policy = "on-request";
            sandbox_mode = "danger-full-access";

            project_root_markers = [
              ".git"
              ".jj"
              ".hg"
              ".sl"
            ];

            tui.status_line = [
              "model-with-reasoning"
              "current-dir"
              "context-remaining"
              "context-used"
              "five-hour-limit"
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

          ".codex/AGENTS.md".source = aiTools.base;

          ".codex/skills".source = aiTools.codex.skills;

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
}
