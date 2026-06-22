{ inputs, ... }:

{
  perSystem =
    { pkgs, system, ... }:
    let
      proxypilot = inputs.pp-t3.packages.${system}.proxypilot;

      t3chatMacOSLaunch = pkgs.writeShellApplication {
        name = "t3chat-macos-launch";
        runtimeInputs = [ proxypilot ];
        text = ''
          set -euo pipefail

          config_path="''${PROXYPILOT_T3CHAT_CONFIG:-$HOME/.config/proxypilot-t3chat/config.yaml}"
          exec ${proxypilot}/bin/proxypilot --config "$config_path"
        '';
      };
    in
    {
      packages.t3chat-macos-launch = t3chatMacOSLaunch;
      apps.t3chat-macos-launch = {
        type = "app";
        program = "${t3chatMacOSLaunch}/bin/t3chat-macos-launch";
      };
    };

  flake.modules.homeManager.proxypilot-t3chat =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      proxypilot = inputs.pp-t3.packages.${pkgs.system}.proxypilot;

      configDir = "${config.home.homeDirectory}/.config/proxypilot-t3chat";
      configPath = "${configDir}/config.yaml";
      logDir = "${config.home.homeDirectory}/Library/Logs/ProxyPilot";

      # Local-only API key used by your local OpenAI-compatible tools.
      # This is not the t3.chat cookie or convexSessionId.
      localApiKey = "local-dev-key";

      configYaml = pkgs.writeText "proxypilot-t3chat-config.yaml" ''
        host: "127.0.0.1"
        port: 8317
        auth-dir: "${config.home.homeDirectory}/.cli-proxy-api"
        api-keys:
          - "${localApiKey}"
        debug: false
      '';

      t3chatImport = pkgs.writeShellApplication {
        name = "t3chat-import";
        runtimeInputs = [ proxypilot ];
        text = ''
          exec ${lib.getExe proxypilot} --config "${configPath}" --t3chat-import
        '';
      };

      t3chatHealth = pkgs.writeShellApplication {
        name = "t3chat-health";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
        ];
        text = ''
          curl -s http://127.0.0.1:8317/v1/models \
            -H 'Authorization: Bearer ${localApiKey}' | jq .
        '';
      };
    in
    {
      home.packages = [
        proxypilot
        inputs.self.packages.${pkgs.system}.t3chat-macos-launch
        t3chatImport
        t3chatHealth
      ];

      # Ensure the generated config is present at the exact path used by the launcher.
      xdg.configFile."proxypilot-t3chat/config.yaml".source = configYaml;

      # Ensure the log directory exists before launchd tries to open the log files.
      home.file."Library/Logs/ProxyPilot/.keep".text = "";

      launchd.agents.proxypilot-t3chat = {
        enable = true;
        config = {
          Label = "org.kendrick.proxypilot-t3chat";
          ProgramArguments = [
            "${inputs.self.packages.${pkgs.system}.t3chat-macos-launch}/bin/t3chat-macos-launch"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          WorkingDirectory = config.home.homeDirectory;
          StandardOutPath = "${logDir}/proxypilot.out.log";
          StandardErrorPath = "${logDir}/proxypilot.err.log";
          EnvironmentVariables = {
            HOME = config.home.homeDirectory;
            PROXYPILOT_T3CHAT_CONFIG = configPath;
            PATH = lib.makeBinPath [
              pkgs.coreutils
              pkgs.bash
              pkgs.curl
              pkgs.jq
            ];
          };
        };
      };

      home.shellAliases = {
        t3chat-import = "t3chat-import";
        t3chat-models = "t3chat-health";
        t3chat-logs = "tail -f ${logDir}/proxypilot.err.log";
        t3chat-status = "launchctl print gui/$(id -u)/org.kendrick.proxypilot-t3chat";
        t3chat-start = "launchctl kickstart -k gui/$(id -u)/org.kendrick.proxypilot-t3chat";
        t3chat-stop = "launchctl bootout gui/$(id -u)/org.kendrick.proxypilot-t3chat 2>/dev/null || true";
        t3chat-restart = "t3chat-stop; t3chat-start";
      };
    };
}
