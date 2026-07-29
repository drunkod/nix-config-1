# Integrate `t3chat-macos-launch` into `m1-min`

This guide shows how to wire the `pp-t3` / ProxyPilot t3.chat launcher into the `m1-min` profile in this Nix configuration.

Target branch and profile:

- Repo: `drunkod/nix-config-1`
- Branch: `fix-graphify-mcp-init`
- Host profile: `m1-min`
- System: `aarch64-darwin`
- User in the current profile: `test`

The recommended integration is a Home Manager `launchd` agent attached to the `m1-min` Home Manager imports. That keeps the server launch declarative while leaving the interactive `t3.chat` cookie import manual.

> Important: the current `pp-t3` flake exposes `.#proxypilot` and `.#import`. If you later add a dedicated upstream `.#t3chat-macos-launch` app, replace the local wrapper below with that app. The pattern stays the same.

---

## 0. How the pieces fit together

`pp-t3` provides the ProxyPilot binary and t3.chat import command:

```bash
nix run github:drunkod/pp-t3/t3go#proxypilot -- --config config.yaml
nix run github:drunkod/pp-t3/t3go#import -- --config config.yaml
```

In this repo, `m1-min` is defined in:

```text
modules/hosts/darwin/m1/default.nix
```

The profile uses:

```nix
flake.darwinConfigurations.m1-min = inputs.darwin.lib.darwinSystem { ... };
flake.modules.darwin.m1-min = {
  host = minimalHost;
  home-manager.users.${minimalHost.user.name} = {
    imports = aiFullImports;
    services.sops.enable = true;
  };
};
```

So the clean integration path is:

1. Add `pp-t3` as a flake input.
2. Add a Home Manager module that:
   - installs `inputs.pp-t3.packages.${pkgs.system}.proxypilot`
   - writes `~/.config/proxypilot-t3chat/config.yaml`
   - creates a `launchd` user agent
   - adds helper aliases for import, logs, and health checks
3. Add that module to `aiFullImports`, which is already used by `m1-min`.
4. Rebuild `m1-min` with `darwin-rebuild switch --flake .#m1-min`.

---

## 1. Add the `pp-t3` flake input

Edit `flake.nix` and add `pp-t3` under `inputs`.

### Recommended for a private GitHub repo

Use SSH so Nix can authenticate with your GitHub SSH key:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
  nixpkgs-master.url = "github:NixOS/nixpkgs/master";

  # ...existing inputs...

  pp-t3 = {
    url = "git+ssh://git@github.com/drunkod/pp-t3.git?ref=t3go";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

### Easier local-dev alternative

Use a local checkout while iterating:

```nix
pp-t3 = {
  url = "path:/Users/test/src/pp-t3";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then update the lock file:

```bash
cd ~/.setup
nix flake lock --update-input pp-t3
```

---

## 2. Add a Home Manager launch module

Create:

```text
modules/programs/proxypilot-t3chat.nix
```

Full module:

```nix
{ inputs, ... }:

{
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

      # This is not a t3.chat secret. It is the local API key that your local tools
      # use when talking to ProxyPilot. Change it if you expose the service beyond
      # localhost, but do not bind the service beyond localhost for this setup.
      localApiKey = "local-dev-key";

      configYaml = pkgs.writeText "proxypilot-t3chat-config.yaml" ''
        host: "127.0.0.1"
        port: 8317
        auth-dir: "${config.home.homeDirectory}/.cli-proxy-api"
        api-keys:
          - "${localApiKey}"
        debug: false
      '';

      t3chatMacOSLaunch = pkgs.writeShellApplication {
        name = "t3chat-macos-launch";
        runtimeInputs = [
          pkgs.coreutils
          proxypilot
        ];
        text = ''
          set -euo pipefail

          mkdir -p "${logDir}"
          mkdir -p "${configDir}"

          exec ${lib.getExe proxypilot} --config "${configPath}"
        '';
      };

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
        t3chatImport
        t3chatHealth
        t3chatMacOSLaunch
      ];

      xdg.configFile."proxypilot-t3chat/config.yaml".source = configYaml;

      launchd.agents.proxypilot-t3chat = {
        enable = true;
        config = {
          Label = "org.kendrick.proxypilot-t3chat";
          ProgramArguments = [
            "${lib.getExe t3chatMacOSLaunch}"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          WorkingDirectory = config.home.homeDirectory;
          StandardOutPath = "${logDir}/proxypilot.out.log";
          StandardErrorPath = "${logDir}/proxypilot.err.log";
          EnvironmentVariables = {
            HOME = config.home.homeDirectory;
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
        t3chat-start = "launchctl kickstart -k gui/$(id -u)/org.kendrick.proxypilot-t3chat";
        t3chat-stop = "launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/proxypilot-t3chat.plist 2>/dev/null || true";
        t3chat-status = "launchctl print gui/$(id -u)/org.kendrick.proxypilot-t3chat";
        t3chat-logs = "tail -f ${logDir}/proxypilot.err.log";
        t3chat-models = "t3chat-health";
      };
    };
}
```

Why this uses Home Manager: `m1-min` already imports Home Manager modules through `aiFullImports`, and Home Manager is the right layer for a per-user LaunchAgent. The service runs after the user logs in, not as a root daemon.

---

## 3. Import the module into `m1-min`

Edit:

```text
modules/hosts/darwin/m1/default.nix
```

Find `aiFullImports`:

```nix
aiFullImports = aiCoreImports ++ [
  config.flake.modules.homeManager.codex
  config.flake.modules.homeManager."pi-coding-agent"
];
```

Change it to:

```nix
aiFullImports = aiCoreImports ++ [
  config.flake.modules.homeManager.codex
  config.flake.modules.homeManager."pi-coding-agent"
  config.flake.modules.homeManager.proxypilot-t3chat
];
```

Because `m1-min` uses `imports = aiFullImports;`, this attaches the ProxyPilot t3.chat LaunchAgent only to the minimal M1 profile.

---

## 4. Rebuild the `m1-min` profile

From the nix-config checkout:

```bash
cd ~/.setup
nix flake check --show-trace
darwin-rebuild switch --flake .#m1-min
```

If `darwin-rebuild` is not in your PATH yet:

```bash
nix build .#darwinConfigurations.m1-min.system
./result/sw/bin/darwin-rebuild switch --flake .#m1-min
```

After activation, verify that the helper commands exist:

```bash
which t3chat-import
which t3chat-health
which t3chat-macos-launch
```

---

## 5. Import the t3.chat browser session

This part stays manual because it handles browser-session secrets.

1. Open `https://t3.chat` in your browser and sign in.
2. Open browser DevTools.
3. Go to the Network tab.
4. Send a normal t3.chat message.
5. Open the `/api/chat` request.
6. Copy the full `Cookie` request header.
7. Copy `convexSessionId` from the request payload.
8. Run:

```bash
t3chat-import
```

When prompted:

```text
Enter t3.chat Cookie header value:
# paste the full Cookie header

Enter convexSessionId from the /api/chat request body:
# paste convexSessionId, or press Enter if ProxyPilot can auto-detect it
```

ProxyPilot stores the imported session in:

```text
~/.cli-proxy-api
```

Re-run `t3chat-import` whenever t3.chat requests start failing with expired-session or upstream `401` style errors.

---

## 6. Start and verify the LaunchAgent

Start or restart the agent:

```bash
t3chat-start
```

Check status:

```bash
t3chat-status
```

Watch logs:

```bash
t3chat-logs
```

List models through the local ProxyPilot server:

```bash
t3chat-models
```

Or call the API directly:

```bash
curl -s http://127.0.0.1:8317/v1/models \
  -H 'Authorization: Bearer local-dev-key' | jq .
```

---

## 7. Test a chat completion

```bash
curl -s http://127.0.0.1:8317/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer local-dev-key' \
  -d '{
    "model": "claude-sonnet-4-6",
    "messages": [
      {"role": "user", "content": "Say hello from the m1-min ProxyPilot launcher."}
    ]
  }' | jq .
```

Use these client settings for OpenAI-compatible tools:

```text
Base URL: http://127.0.0.1:8317/v1
API key : local-dev-key
```

---

## 8. Optional: expose a flake app from nix-config too

The Home Manager service above is enough for automatic launch. If you also want `nix run .#t3chat-macos-launch` from this config repo, extend `modules/programs/proxypilot-t3chat.nix` with a `perSystem` app.

Full combined version:

```nix
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
      localApiKey = "local-dev-key";
      configYaml = pkgs.writeText "proxypilot-t3chat-config.yaml" ''
        host: "127.0.0.1"
        port: 8317
        auth-dir: "${config.home.homeDirectory}/.cli-proxy-api"
        api-keys:
          - "${localApiKey}"
        debug: false
      '';
    in
    {
      home.packages = [
        proxypilot
        inputs.self.packages.${pkgs.system}.t3chat-macos-launch
      ];

      xdg.configFile."proxypilot-t3chat/config.yaml".source = configYaml;

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
          };
        };
      };
    };
}
```

Then run manually with:

```bash
nix run .#t3chat-macos-launch
```

---

## 9. Alternative: use nix-darwin `launchd.user.agents`

Use this if you prefer the service at the nix-darwin layer instead of Home Manager. This is less targeted to the user profile but still valid for a user LaunchAgent.

Example module:

```nix
{ config, inputs, lib, pkgs, ... }:

let
  userName = config.host.user.name;
  homeDir = "/Users/${userName}";
  proxypilot = inputs.pp-t3.packages.${pkgs.system}.proxypilot;
  configPath = "${homeDir}/.config/proxypilot-t3chat/config.yaml";
  logDir = "${homeDir}/Library/Logs/ProxyPilot";
  launcher = pkgs.writeShellApplication {
    name = "t3chat-macos-launch";
    runtimeInputs = [ proxypilot ];
    text = ''
      mkdir -p "${logDir}"
      exec ${lib.getExe proxypilot} --config "${configPath}"
    '';
  };
in
{
  launchd.user.agents.proxypilot-t3chat = {
    serviceConfig = {
      Label = "org.kendrick.proxypilot-t3chat";
      ProgramArguments = [ "${lib.getExe launcher}" ];
      RunAtLoad = true;
      KeepAlive = true;
      WorkingDirectory = homeDir;
      StandardOutPath = "${logDir}/proxypilot.out.log";
      StandardErrorPath = "${logDir}/proxypilot.err.log";
      EnvironmentVariables = {
        HOME = homeDir;
      };
    };
  };
}
```

For this repository, the Home Manager version is the better first choice because the `m1-min` profile already composes user AI tooling through Home Manager imports.

---

## 10. Troubleshooting

| Symptom | Check | Fix |
|---|---|---|
| `attribute 'pp-t3' missing` | `flake.nix` input not added or lock file stale | Run `nix flake lock --update-input pp-t3` |
| `No such file or directory: config.yaml` | Config file was not linked yet | Run `darwin-rebuild switch --flake .#m1-min` again and check `~/.config/proxypilot-t3chat/config.yaml` |
| Agent starts then exits | Check logs | `tail -n 200 ~/Library/Logs/ProxyPilot/proxypilot.err.log` |
| `missing t3chat cookies` | Browser session was not imported | Run `t3chat-import` |
| Upstream `401` or empty responses | t3.chat cookies expired | Repeat the browser extraction and `t3chat-import` |
| Port already in use | Another ProxyPilot is running | Stop the old process or change `port: 8317` in the generated config |
| Private repo fetch fails | Nix cannot authenticate to `pp-t3` | Use the `git+ssh://git@github.com/...` input and verify `ssh -T git@github.com` |

---

## 11. Minimal patch summary

```diff
diff --git a/flake.nix b/flake.nix
@@
     graphify-src = {
       url = "github:safishamsi/graphify/v8";
       flake = false;
     };
+
+    pp-t3 = {
+      url = "git+ssh://git@github.com/drunkod/pp-t3.git?ref=t3go";
+      inputs.nixpkgs.follows = "nixpkgs";
+    };
   };
```

```diff
diff --git a/modules/hosts/darwin/m1/default.nix b/modules/hosts/darwin/m1/default.nix
@@
   aiFullImports = aiCoreImports ++ [
     config.flake.modules.homeManager.codex
     config.flake.modules.homeManager."pi-coding-agent"
+    config.flake.modules.homeManager.proxypilot-t3chat
   ];
```

Then add the new file:

```text
modules/programs/proxypilot-t3chat.nix
```

using the full module from step 2.
