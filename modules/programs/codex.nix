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
      exoEnabled = false; # Set to true if you run a local exo cluster service
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
          pkgs.llm-agents.codex
          pkgs.jq
        ];

        shellAliases = {
          codex-deep = "codex --profile deep";
          codex-long = "codex --profile long -c model_context_window=1000000 -c model_auto_compact_token_limit=850000";
          codex-nano = "codex --profile nano";
          codex-offline = "codex --profile offline";
          codex-quick = "codex --profile quick";
          codex-spark = "codex --profile spark";
          codex-unsafe = "codex --profile unsafe";
        }
        // lib.optionalAttrs exoEnabled {
          codex-exo = ''f(){ model="$1"; shift; codex -c model_provider='"exo"' -m "$model" "$@"; }; f'';
          codex-exo-coder = ''codex -c model_provider='"exo"' -m mlx-community/Qwen3-Coder-Next-4bit'';
          codex-exo-gpt-oss = ''codex -c model_provider='"exo"' -m mlx-community/gpt-oss-20b-MXFP4-Q8'';
          codex-exo-qwen = ''codex -c model_provider='"exo"' -m mlx-community/Qwen3.6-35B-A3B-5bit'';
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
            model_providers = lib.optionalAttrs exoEnabled {
              exo = {
                name = "exo (local cluster)";
                base_url = "http://localhost:52415/v1";
                wire_api = "responses";
                requires_openai_auth = false;
                request_max_retries = 1;
                stream_max_retries = 1;
                stream_idle_timeout_ms = 300000;
              };
            };
            notify = [ (lib.getExe codexNotify) ];
            personality = "pragmatic";
            approval_policy = "on-request";
            sandbox_mode = "danger-full-access";

            mcp_servers = if (config.programs.mcp.enable or false) then (
              lib.mapAttrs (name: server:
                lib.filterAttrs (n: v: v != null && v != [] && v != {}) {
                  command = server.command;
                  args = server.args or [];
                  env = server.env or {};
                }
              ) config.programs.mcp.servers
            ) else {};

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

            projects =
              let
                trustedProjects = [
                  "Documents/work"
                  "Documents/work/fcast-android-sender"
                ];
              in
              {
                ${config.home.homeDirectory}.trust_level = "trusted";
              }
              // builtins.listToAttrs (
                map (project: {
                  name = "${config.home.homeDirectory}/${project}";
                  value = {
                    trust_level = "trusted";
                  };
                }) trustedProjects
              );
          };

          ".codex/AGENTS.md".source = aiTools.base;

          ".codex/skills".source = aiTools.codex.skills;

          ".codex/rules/read-only.md".text = builtins.readFile ./codex-rules.txt;
        };
      };
    };
}
