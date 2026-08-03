{
  flake.modules.homeManager.repo-harness =
    {
      lib,
      pkgs,
      ...
    }:
    let
      repoHarnessSource =
        "git+https://github.com/drunkod/repo-harness.git#agent/chatgpt-github-create-mvp";

      repoHarnessRuntimeInputs = with pkgs; [
        bash
        bun
        coreutils
        curl
        findutils
        git
        jq
      ];

      # Keep the mutable Bun installation explicit, but provide a stable command
      # after Home Manager activation. This avoids routing an expected first-run
      # state through the shell's command-not-found handler.
      repoHarnessLauncher = pkgs.writeShellApplication {
        name = "repo-harness";
        text = ''
          set -euo pipefail

          export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
          cli="$BUN_INSTALL/bin/repo-harness"

          if [ ! -x "$cli" ]; then
            printf '%s\n' \
              "repo-harness CLI is not installed yet." \
              "" \
              "Run:" \
              "  rh-bootstrap" \
              "" \
              "Then verify:" \
              "  repo-harness --version" >&2
            exit 127
          fi

          exec "$cli" "$@"
        '';
      };

      repoHarnessBootstrap = pkgs.writeShellApplication {
        name = "repo-harness-bootstrap";
        runtimeInputs = repoHarnessRuntimeInputs;
        text = ''
          set -euo pipefail

          export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
          mkdir -p "$BUN_INSTALL/bin"
          export PATH="$BUN_INSTALL/bin:$PATH"

          echo "Installing or refreshing repo-harness CLI with Bun..."
          bun add -g ${lib.escapeShellArg repoHarnessSource}

          echo
          echo "repo-harness CLI:"
          "$BUN_INSTALL/bin/repo-harness" --version

          echo
          echo "Host config was not changed. To inspect generated host adapters safely, run:"
          echo "  rh-generate-host-config"

          echo
          echo "Next steps inside a target repository:"
          echo "  rh-adopt"
          echo "  repo-harness adopt"
          echo "  repo-harness run check-task-workflow --strict"
        '';
      };

      repoHarnessGenerateHostConfig = pkgs.writeShellApplication {
        name = "repo-harness-generate-host-config";
        runtimeInputs = repoHarnessRuntimeInputs;
        text = ''
          set -euo pipefail

          workdir="$(mktemp -d "''${TMPDIR:-/tmp}/repo-harness-host-config.XXXXXX")"
          generated_home="$workdir/home"

          mkdir -p "$generated_home"

          export HOME="$generated_home"
          export XDG_CONFIG_HOME="$generated_home/.config"
          export XDG_STATE_HOME="$generated_home/.local/state"
          export XDG_CACHE_HOME="$generated_home/.cache"
          export BUN_INSTALL="$generated_home/.bun"
          export PATH="$BUN_INSTALL/bin:$PATH"

          mkdir -p \
            "$XDG_CONFIG_HOME" \
            "$XDG_STATE_HOME" \
            "$XDG_CACHE_HOME" \
            "$BUN_INSTALL/bin"

          echo "Generating repo-harness host config in an isolated HOME:"
          echo "  $generated_home"
          echo

          bun add -g ${lib.escapeShellArg repoHarnessSource}
          "$BUN_INSTALL/bin/repo-harness" install

          echo
          echo "Generated files:"
          found=0
          while IFS= read -r file; do
            found=1
            printf '  %s\n' "''${file#"$generated_home"/}"
          done < <(find "$generated_home" -type f | sort)

          if [ "$found" -eq 0 ]; then
            echo "  <none>"
          fi

          echo
          echo "Inspect likely host-adapter outputs:"
          echo "  cat '$generated_home/.claude/settings.json'"
          echo "  cat '$generated_home/.codex/hooks.json'"
          echo "  find '$generated_home/.claude' -maxdepth 4 -type f | sort"
          echo "  find '$generated_home/.codex' -maxdepth 4 -type f | sort"
          echo "  find '$generated_home/.repo-harness' -maxdepth 4 -type f | sort"
          echo
          echo "Nothing was written to your real HOME. Port wanted files into nix-config-1 manually."
        '';
      };

      repoHarnessAdoptCurrent = pkgs.writeShellApplication {
        name = "repo-harness-adopt-current";
        runtimeInputs = repoHarnessRuntimeInputs;
        text = ''
          set -euo pipefail

          export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
          cli="$BUN_INSTALL/bin/repo-harness"

          if [ ! -x "$cli" ]; then
            echo "repo-harness CLI is not installed. Run rh-bootstrap first." >&2
            exit 127
          fi

          echo "Previewing repo-harness adoption for: $PWD"
          "$cli" adopt --dry-run

          echo
          echo "If the dry run looks correct, apply it with:"
          echo "  repo-harness adopt"
        '';
      };

      repoHarnessCheck = pkgs.writeShellApplication {
        name = "repo-harness-check";
        runtimeInputs = repoHarnessRuntimeInputs;
        text = ''
          set -euo pipefail

          export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
          cli="$BUN_INSTALL/bin/repo-harness"

          if [ ! -x "$cli" ]; then
            echo "repo-harness CLI is not installed. Run rh-bootstrap first." >&2
            exit 127
          fi

          exec "$cli" setup check --json
        '';
      };
    in
    {
      home = {
        packages = [
          pkgs.bun
          pkgs.jq
          repoHarnessLauncher
          repoHarnessBootstrap
          repoHarnessGenerateHostConfig
          repoHarnessAdoptCurrent
          repoHarnessCheck
        ];

        sessionPath = [
          "$HOME/.bun/bin"
        ];

        shellAliases = {
          rh-bootstrap = "repo-harness-bootstrap";
          rh-generate-host-config = "repo-harness-generate-host-config";
          rh-adopt = "repo-harness-adopt-current";
          rh-check = "repo-harness-check";
        };
      };

      programs.zsh.initContent = lib.mkAfter ''
        export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
        case ":$PATH:" in
          *":$BUN_INSTALL/bin:"*) ;;
          *) export PATH="$BUN_INSTALL/bin:$PATH" ;;
        esac
      '';
    };
}
