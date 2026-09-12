{
  flake.modules.homeManager.repo-harness =
    {
      lib,
      pkgs,
      ...
    }:
    let
      # repo-harness 0.19.0 requires Bun >= 1.4.0 and Herdr >= 0.9.0. The
      # current nixpkgs pins are older, so keep these two runtime dependencies
      # explicit and reproducible until nixpkgs catches up.
      repoHarnessBunSource = pkgs.fetchzip {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.0/bun-darwin-aarch64.zip";
        hash = "sha256-rEW+fpUdE+0+hmCDww1M4+59TwoEhZRopOnSGNLAEPU=";
        stripRoot = false;
      };
      repoHarnessBun = pkgs.runCommand "repo-harness-bun-1.4.0" { } ''
        mkdir -p "$out/bin"
        install -m 0755 "${repoHarnessBunSource}/bun-darwin-aarch64/bun" "$out/bin/bun"
      '';

      repoHarnessHerdrSource = pkgs.fetchurl {
        url = "https://github.com/herdrdev/herdr/releases/download/v0.9.0/herdr-macos-aarch64";
        hash = "sha256-MrU98JhyYoBZx4mmnwKmuOKeFN3yZxFCHzRj9wwa7xc=";
      };
      repoHarnessHerdr = pkgs.runCommand "repo-harness-herdr-0.9.0" { } ''
        mkdir -p "$out/bin"
        install -m 0755 "${repoHarnessHerdrSource}" "$out/bin/herdr"
      '';

      repoHarnessSource =
        "git+https://github.com/drunkod/repo-harness.git#main";

      repoHarnessRuntimeInputs = [
        pkgs.bash
        repoHarnessBun
        pkgs.coreutils
        pkgs.curl
        pkgs.findutils
        pkgs.git
        repoHarnessHerdr
        pkgs.jq
        pkgs.nodejs_24
      ];

      # Remove the registered global dependency first so switching Git sources
      # remains deterministic across Bun versions and prior installations.
      repoHarnessInstall = ''
        global_manifest="$BUN_INSTALL/install/global/package.json"

        if [ -f "$global_manifest" ] \
          && jq -e '(.dependencies // {}) | has("repo-harness")' "$global_manifest" >/dev/null
        then
          echo "Removing existing repo-harness global package before switching sources..."
          bun remove -g repo-harness
        fi

        bun add -g ${lib.escapeShellArg repoHarnessSource}
      '';

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
          ${repoHarnessInstall}

          echo
          echo "repo-harness CLI:"
          "$BUN_INSTALL/bin/repo-harness" --version

          echo
          echo "Host config was not changed directly."
          echo "Sync the current Codex adapter projection into Nix with:"
          echo "  rh-sync-host-config"
          echo "Inspect the full upstream host projection with:"
          echo "  rh-generate-host-config"

          echo
          echo "Next steps inside a target repository:"
          echo "  rh-init"
          echo "  repo-harness init"
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

          ${repoHarnessInstall}
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

      repoHarnessSyncHostConfig = pkgs.writeShellApplication {
        name = "repo-harness-sync-host-config";
        runtimeInputs = repoHarnessRuntimeInputs;
        text = ''
          set -euo pipefail

          export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
          cli="$BUN_INSTALL/bin/repo-harness"
          nix_config_root="''${REPO_HARNESS_NIX_CONFIG_ROOT:-$HOME/nix-config}"
          mode=apply

          while [ "$#" -gt 0 ]; do
            case "$1" in
              --check)
                mode=check
                shift
                ;;
              --nix-config)
                [ "$#" -ge 2 ] || { echo "--nix-config requires a path" >&2; exit 2; }
                nix_config_root="$2"
                shift 2
                ;;
              -h|--help)
                cat <<'EOF'
Usage: repo-harness-sync-host-config [--check] [--nix-config <path>]

Generate the current Repo Harness Codex host adapter in an isolated HOME and
sync its hooks projection into the Nix configuration. The real ~/.codex files
are never mutated by this command.
EOF
                exit 0
                ;;
              *)
                echo "unknown argument: $1" >&2
                exit 2
                ;;
            esac
          done

          [ -x "$cli" ] || { echo "repo-harness CLI is not installed; run rh-bootstrap first" >&2; exit 127; }
          [ -d "$nix_config_root/.git" ] || { echo "Nix config repo not found: $nix_config_root" >&2; exit 1; }

          target_dir="$nix_config_root/modules/programs/repo-harness"
          target="$target_dir/codex-hooks.json"
          codex_module="$nix_config_root/modules/programs/codex.nix"
          workdir="$(mktemp -d "''${TMPDIR:-/tmp}/repo-harness-host-sync.XXXXXX")"
          trap 'rm -rf "$workdir"' EXIT
          generated_home="$workdir/home"
          mkdir -p "$generated_home"

          HOME="$generated_home" \
          XDG_CONFIG_HOME="$generated_home/.config" \
          XDG_STATE_HOME="$generated_home/.local/state" \
          XDG_CACHE_HOME="$generated_home/.cache" \
            "$cli" install --target codex --location global >/dev/null

          generated_hooks="$generated_home/.codex/hooks.json"
          generated_config="$generated_home/.codex/config.toml"

          jq -e '
            (.hooks | type == "object")
            and ([.hooks[]?[]? | .hooks[]? | select(.command | contains("repo-harness-managed-hook-v1"))] | length > 0)
          ' "$generated_hooks" >/dev/null

          config_payload="$(grep -Ev '^[[:space:]]*(#|$)' "$generated_config")"
          if [ "$config_payload" != "default_mode_request_user_input = true" ]; then
            echo "Repo Harness generated unexpected Codex config requirements:" >&2
            cat "$generated_config" >&2
            echo "Review and port them into modules/programs/codex.nix before syncing hooks." >&2
            exit 1
          fi

          grep -Fq 'default_mode_request_user_input = true;' "$codex_module" || {
            echo "modules/programs/codex.nix is missing default_mode_request_user_input = true" >&2
            exit 1
          }

          if [ -f "$target" ] && cmp -s "$generated_hooks" "$target"; then
            echo "Repo Harness Codex host projection is current."
            exit 0
          fi

          if [ "$mode" = check ]; then
            echo "Repo Harness Codex host projection is stale or missing: $target" >&2
            echo "Run: rh-sync-host-config" >&2
            exit 1
          fi

          mkdir -p "$target_dir"
          tmp_target="$target.tmp.$$"
          cp "$generated_hooks" "$tmp_target"
          mv "$tmp_target" "$target"

          echo "Updated Repo Harness Codex host projection:"
          echo "  $target"
          echo
          echo "Review and activate it with:"
          echo "  cd '$nix_config_root'"
          echo "  git diff -- modules/programs/codex.nix modules/programs/repo-harness.nix modules/programs/repo-harness/codex-hooks.json"
          echo "  sudo darwin-rebuild switch --flake .#m1-min"
          echo
          echo "Then restart Codex and accept any new hook trust prompt."
        '';
      };

      repoHarnessInitCurrent = pkgs.writeShellApplication {
        name = "repo-harness-init-current";
        runtimeInputs = repoHarnessRuntimeInputs;
        text = ''
          set -euo pipefail

          export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
          cli="$BUN_INSTALL/bin/repo-harness"

          if [ ! -x "$cli" ]; then
            echo "repo-harness CLI is not installed. Run rh-bootstrap first." >&2
            exit 127
          fi

          echo "Previewing repo-harness initialization for: $PWD"
          "$cli" init --dry-run

          echo
          echo "If the dry run looks correct, apply it with:"
          echo "  repo-harness init"
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
          repoHarnessBun
          repoHarnessHerdr
          pkgs.jq
          pkgs.nodejs_24
          repoHarnessLauncher
          repoHarnessBootstrap
          repoHarnessGenerateHostConfig
          repoHarnessSyncHostConfig
          repoHarnessInitCurrent
          repoHarnessCheck
        ];

        sessionPath = [
          "$HOME/.bun/bin"
        ];

        shellAliases = {
          rh-bootstrap = "repo-harness-bootstrap";
          rh-generate-host-config = "repo-harness-generate-host-config";
          rh-sync-host-config = "repo-harness-sync-host-config";
          rh-init = "repo-harness-init-current";
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
