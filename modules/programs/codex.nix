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
      codexPackage = pkgs.llm-agents.codex;
      wazaProjection = builtins.fromJSON (
        builtins.readFile ./repo-harness/waza-source.json
      );
      wazaRepoParts = lib.splitString "/" wazaProjection.source_repo;
      wazaSource = pkgs.fetchFromGitHub {
        owner = builtins.elemAt wazaRepoParts 0;
        repo = builtins.elemAt wazaRepoParts 1;
        rev = wazaProjection.rev;
        hash = wazaProjection.hash;
      };
      wazaSkills = wazaProjection.managed_skills;
      wazaSharedRules = wazaProjection.shared_rules;
      codexSkills = pkgs.runCommand "codex-skills-with-waza" { } ''
        mkdir -p "$out"
        cp -R ${aiTools.codex.skills}/. "$out/"
        chmod -R u+w "$out"
        for skill in ${lib.concatStringsSep " " wazaSkills}; do
          rm -rf "$out/$skill"
          cp -R "${wazaSource}/skills/$skill" "$out/$skill"
        done
      '';
      trustedWorkspaceRoot = "${config.home.homeDirectory}/Documents/work";
      repoHarnessHookTrust = builtins.fromJSON (
        builtins.readFile ./repo-harness/codex-hook-trust.json
      );
      codexLauncher = pkgs.writeShellApplication {
        name = "codex";
        runtimeInputs = [
          pkgs.git
          pkgs.jq
        ];
        text = ''
          set -euo pipefail

          codex_bin=${lib.escapeShellArg (lib.getExe codexPackage)}
          trusted_root=${lib.escapeShellArg trustedWorkspaceRoot}
          project_root=""

          if root="$(${lib.getExe pkgs.git} rev-parse --show-toplevel 2>/dev/null)"; then
            case "$root/" in
              "$trusted_root/"*) project_root="$root" ;;
            esac
          fi

          if [ -n "$project_root" ]; then
            quoted_root="$(printf '%s' "$project_root" | ${lib.getExe pkgs.jq} -Rs '.')"
            exec "$codex_bin" -c "projects.$quoted_root.trust_level=\"trusted\"" "$@"
          fi

          exec "$codex_bin" "$@"
        '';
      };
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
          codexLauncher
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

        file =
          {
          ".codex/config.toml".source = settingsFormat.generate "codex-config.toml" {
            # Repo Harness owns this host-level Codex capability. Keep it in the
            # Nix-owned config rather than letting the mutable upstream installer
            # edit ~/.codex/config.toml directly.
            default_mode_request_user_input = true;

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

            # Codex persists hook approvals in config.toml, which is immutable on
            # this Home Manager host. Generate the trusted hashes from Codex's own
            # hooks/list API and project them declaratively instead.
            hooks.state = lib.mapAttrs' (selector: trustedHash:
              lib.nameValuePair
                "${config.home.homeDirectory}/.codex/hooks.json:${selector}"
                { trusted_hash = trustedHash; }
            ) repoHarnessHookTrust;

            model = "gpt-5.6-luna";
            model_auto_compact_token_limit = 240000;
            model_context_window = 272000;
            model_reasoning_effort = "medium";
            plan_mode_reasoning_effort = "medium";
            service_tier = "priority";
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

              # Faster implementation loop for routine coding tasks.
              quick = {
                model_reasoning_effort = "medium";
                model = "gpt-5.6-luna";
                model_reasoning_summary = "none";
                model_verbosity = "low";
                plan_mode_reasoning_effort = "medium";
                service_tier = "priority";
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
                # Codex project trust is exact-path, not inherited. The CLI
                # launcher below supplies exact trust dynamically for Git roots
                # under Documents/work; keep explicit entries for non-wrapper
                # clients that open these known repositories directly.
                trustedProjects = [
                  "Documents/work"
                  "Documents/work/browser-extension-chat-jazz"
                  "Documents/work/fcast-android-sender"
                  "Documents/work/omnigent"
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

          # Generated from the currently installed Repo Harness runtime by
          # `rh-sync-host-config`; Home Manager remains the sole owner of the
          # real user-level Codex adapter.
          ".codex/hooks.json".source = ./repo-harness/codex-hooks.json;

          ".codex/AGENTS.md".source = aiTools.base;

          # Codex runtime skills are Nix-owned, but the parent directory must
          # stay writable because Codex 0.154+ materializes its own system-skill
          # metadata there. Recursive projection links managed files below the
          # directory instead of replacing ~/.codex/skills with a store symlink.
          ".codex/skills" = {
            source = codexSkills;
            recursive = true;
          };

            ".codex/rules/read-only.md".text = builtins.readFile ./codex-rules.txt;
          }
          // builtins.listToAttrs (
            map (rule: {
              name = ".codex/rules/${rule}";
              value.source = "${wazaSource}/rules/${rule}";
            }) wazaSharedRules
          );
      };

      # Older generations projected ~/.codex/skills as one store-backed symlink.
      # Codex 0.154+ writes its own system-skill metadata under that directory, so
      # migrate only the Home-Manager-owned parent link to a writable directory
      # before recursive child links are installed.
      home.activation.codexSkillsWritableRoot = lib.hm.dag.entryBetween
        [ "linkGeneration" ]
        [ "writeBoundary" ]
        ''
          skills_root="$HOME/.codex/skills"
          if [ -L "$skills_root" ]; then
            target="$(readlink "$skills_root" || true)"
            case "$target" in
              /nix/store/*-home-manager-files/.codex/skills)
                run rm "$skills_root"
                run mkdir -p "$skills_root"
                ;;
            esac
          fi
        '';
    };
}
