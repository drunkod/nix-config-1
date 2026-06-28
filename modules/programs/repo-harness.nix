{
  flake.modules.homeManager.repo-harness =
    {
      lib,
      pkgs,
      ...
    }:
    let
      repoHarnessRuntimeInputs = with pkgs; [
        bash
        bun
        coreutils
        curl
        git
        jq
      ];

      repoHarnessBootstrap = pkgs.writeShellApplication {
        name = "repo-harness-bootstrap";
        runtimeInputs = repoHarnessRuntimeInputs;
        text = ''
          set -euo pipefail

          export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
          mkdir -p "$BUN_INSTALL/bin"
          export PATH="$BUN_INSTALL/bin:$PATH"

          echo "Installing or refreshing repo-harness with Bun..."
          bun add -g repo-harness

          echo "Configuring repo-harness host adapters for Claude/Codex..."
          repo-harness install

          echo
          echo "repo-harness status:"
          repo-harness status || true

          echo
          echo "Next steps inside a target repository:"
          echo "  repo-harness adopt --dry-run"
          echo "  repo-harness adopt"
          echo "  bash scripts/check-task-workflow.sh --strict"
        '';
      };

      repoHarnessAdoptCurrent = pkgs.writeShellApplication {
        name = "repo-harness-adopt-current";
        runtimeInputs = repoHarnessRuntimeInputs;
        text = ''
          set -euo pipefail

          export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
          export PATH="$BUN_INSTALL/bin:$PATH"

          if ! command -v repo-harness >/dev/null 2>&1; then
            echo "repo-harness is not installed. Run repo-harness-bootstrap first." >&2
            exit 127
          fi

          echo "Previewing repo-harness adoption for: $PWD"
          repo-harness adopt --dry-run

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
          export PATH="$BUN_INSTALL/bin:$PATH"

          if ! command -v repo-harness >/dev/null 2>&1; then
            echo "repo-harness is not installed. Run repo-harness-bootstrap first." >&2
            exit 127
          fi

          repo-harness setup check --json
        '';
      };
    in
    {
      home = {
        packages = [
          pkgs.bun
          pkgs.jq
          repoHarnessBootstrap
          repoHarnessAdoptCurrent
          repoHarnessCheck
        ];

        sessionPath = [
          "$HOME/.bun/bin"
        ];

        shellAliases = {
          rh-bootstrap = "repo-harness-bootstrap";
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
