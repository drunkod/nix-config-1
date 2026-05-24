{
  flake.modules.homeManager.codex =
    { config, pkgs, ... }:
    let
      settingsFormat = pkgs.formats.toml { };
      rules = import ./rules.nix;
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

            notify = [
              "${
                pkgs.writeShellApplication {
                  name = "codex-notify";
                  runtimeInputs = [
                    pkgs.jq
                    pkgs.terminal-notifier
                  ];
                  text = ''
                    payload="$1"
                    event_type="$(printf '%s' "$payload" | jq -r '.type // ""')"
                    [ "$event_type" = "agent-turn-complete" ] || exit 0

                    message="$(printf '%s' "$payload" | jq -r '.["last-assistant-message"] // "Turn complete"')"
                    summary="$(printf '%s' "$message" | cut -c1-180)"
                    terminal-notifier -title "Codex" -message "$summary" -group "codex-turn" >/dev/null 2>&1 || true
                  '';
                }
              }/bin/codex-notify"
            ];

            personality = "pragmatic";

            project_root_markers = [
              ".git"
              ".jj"
              ".hg"
              ".sl"
            ];

            approval_policy = "on-request";
            sandbox_mode = "danger-full-access";

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

            projects.${config.home.homeDirectory} = {
              trust_level = "trusted";
            };
          };

          ".codex/rules/read-only.md".text = rules."read-only";
        };
      };
    };
}
