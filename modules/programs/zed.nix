{
  flake.modules.homeManager.zed =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      settingsFormat = pkgs.formats.json { };
      aiTools = import ../../ai-tools { inherit lib; };
      zedCli = pkgs.writeShellScriptBin "zed" ''
        exec /Applications/Zed.app/Contents/MacOS/cli "$@"
      '';
    in
    {
      # Nix language server + formatter, installed declaratively so Zed never
      # depends on them being on PATH (Zed launched from Dock/Finder on macOS
      # does not inherit the shell PATH).
      home.packages = [
        pkgs.nil
        pkgs.nixfmt-rfc-style
        zedCli
      ];

      home.file.".agents/skills".source = aiTools.skillsDir;

      launchd.agents.zed-environment = {
        enable = true;
        config = {
          Label = "org.kendrick.zed-environment";
          ProgramArguments = [
            "/bin/launchctl"
            "setenv"
            "PROXYPILOT_T3CHAT_API_KEY"
            "local-dev-key"
          ];
          RunAtLoad = true;
        };
      };

      xdg.configFile."zed/settings.json".source = settingsFormat.generate "zed-settings.json" (
        {
          telemetry = {
            diagnostics = false;
            metrics = false;
          };
          ui_font_size = 16;
          buffer_font_size = 14;
          # Follow macOS light/dark appearance automatically
          theme = {
            dark = "One Dark";
            light = "One Light";
            mode = "system";
          };
          # Point the Nix extension at the nil binary by absolute store path,
          # and let nil format via nixfmt.
          lsp = {
            nil = {
              binary.path = lib.getExe pkgs.nil;
              settings.formatting.command = [ (lib.getExe pkgs.nixfmt-rfc-style) ];
            };
          };
          languages.Nix.language_servers = [ "nil" ];

          agent = {
            # Zed profiles control tool availability separately from tool permissions.
            # Keep Luna as the model, but use Zed's maintained Write profile by default
            # so new Agent Panel threads can read, edit, and run commands.
            default_profile = "write";
            default_model = {
              provider = "openai-subscribed";
              model = "gpt-5.6-luna";
              enable_thinking = false;
              effort = "low";
            };
            tool_permissions = {
              default = "allow";
            };
            sandbox_permissions.allow_unsandboxed = true;
            profiles."luna-filesystem-test" = {
              name = "Luna Filesystem Test";
              tools = {
                find_path = true;
                read_file = true;
              };
              enable_all_context_servers = false;
              context_servers = { };
            };
          };
          language_models = {
            openai_compatible = {
              proxypilot-t3chat = {
                api_url = "http://127.0.0.1:8317/v1";
                available_models = [
                  {
                    name = "gpt-5.6-luna";
                    display_name = "GPT-5.6 Luna";
                    max_tokens = 128000;
                    max_output_tokens = 16384;
                    reasoning_effort = "medium";
                    capabilities = {
                      tools = true;
                      images = true;
                      parallel_tool_calls = false;
                      prompt_cache_key = false;
                      chat_completions = true;
                      interleaved_reasoning = true;
                      max_tokens_parameter = false;
                    };
                  }
                  {
                    name = "gpt-5.6-sol";
                    display_name = "GPT-5.6 Sol";
                    max_tokens = 24000;
                    max_output_tokens = 16384;
                    reasoning_effort = "medium";
                    capabilities = {
                      tools = true;
                      images = true;
                      parallel_tool_calls = false;
                      prompt_cache_key = false;
                      chat_completions = true;
                      interleaved_reasoning = true;
                      max_tokens_parameter = false;
                    };
                  }
                  {
                    name = "gpt-5.6-terra";
                    display_name = "GPT-5.6 Terra";
                    max_tokens = 64000;
                    max_output_tokens = 16384;
                    reasoning_effort = "medium";
                    capabilities = {
                      tools = true;
                      images = true;
                      parallel_tool_calls = false;
                      prompt_cache_key = false;
                      chat_completions = true;
                      interleaved_reasoning = true;
                      max_tokens_parameter = false;
                    };
                  }
                ];
              };
            };
          };
        }
        // lib.optionalAttrs (config.programs.mcp.enable or false) {
          context_servers =
            (lib.mapAttrs (name: server: {
              command = server.command;
              args = server.args or [ ];
              env = server.env or { };
            }) (lib.removeAttrs config.programs.mcp.servers [ "codewebchat" ]))
            // {
              touchpoint-http = {
                url = "http://127.0.0.1:8081/mcp";
              };
            };
        }
      );
    };
}
