{
  flake.modules.homeManager.repo-harness =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Repo Harness 0.19.0 requires Bun >= 1.4.0 and Herdr >= 0.9.0.
      # Pin platform-correct release assets until nixpkgs carries those floors.
      platform = pkgs.stdenv.hostPlatform.system;
      bunRelease =
        ({
          "aarch64-darwin" = {
            asset = "bun-darwin-aarch64.zip";
            directory = "bun-darwin-aarch64";
            hash = "sha256-xmnpf2Fk4cluBwF0jbmN+ndJKQjL2DlMdVcTSnNd44E=";
          };
          "x86_64-darwin" = {
            asset = "bun-darwin-x64.zip";
            directory = "bun-darwin-x64";
            hash = "sha256-HQIRuPHcmRGCNEaHrRXnLuhvFUhFpff6R3mUzTQd2bA=";
          };
          "aarch64-linux" = {
            asset = "bun-linux-aarch64.zip";
            directory = "bun-linux-aarch64";
            hash = "sha256-SxozLuhhmD65O8/m93D/+U4+MbLDiL2uo8jtNeWO7Q4=";
          };
          "x86_64-linux" = {
            asset = "bun-linux-x64.zip";
            directory = "bun-linux-x64";
            hash = "sha256-LQP7X7g6yLVnrKCigbLOGhoZ1Ij1bClo2Iw/Jekv5FI=";
          };
        }).${platform} or (throw "repo-harness: unsupported platform ${platform}");

      herdrRelease =
        ({
          "aarch64-darwin" = {
            asset = "herdr-macos-aarch64";
            hash = "sha256-MrU98JhyYoBZx4mmnwKmuOKeFN3yZxFCHzRj9wwa7xc=";
          };
          "x86_64-darwin" = {
            asset = "herdr-macos-x86_64";
            hash = "sha256-0MkgsqEmp0gJ+hSRQRyaCXpEeGysnCylG4GKmVWBzxY=";
          };
          "aarch64-linux" = {
            asset = "herdr-linux-aarch64";
            hash = "sha256-nI2yD7fnQnsTjVNnET8WIf/TGfL2XW8AniWUApEV8NI=";
          };
          "x86_64-linux" = {
            asset = "herdr-linux-x86_64";
            hash = "sha256-T6GgEVjdgEPaktMbJweAsNzBBgMDjZthysTYGrY/tx8=";
          };
        }).${platform} or (throw "repo-harness: unsupported platform ${platform}");

      repoHarnessBunSource = pkgs.fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.0/${bunRelease.asset}";
        hash = bunRelease.hash;
      };
      repoHarnessBun =
        pkgs.runCommand "repo-harness-bun-1.4.0"
          {
            nativeBuildInputs = [ pkgs.unzip ];
          }
          ''
            unzip -q "${repoHarnessBunSource}" -d unpacked
            mkdir -p "$out/bin"
            install -m 0755 "unpacked/${bunRelease.directory}/bun" "$out/bin/bun"
          '';

      repoHarnessHerdrSource = pkgs.fetchurl {
        url = "https://github.com/herdrdev/herdr/releases/download/v0.9.0/${herdrRelease.asset}";
        hash = herdrRelease.hash;
      };
      repoHarnessHerdr = pkgs.runCommand "repo-harness-herdr-0.9.0" { } ''
        mkdir -p "$out/bin"
        install -m 0755 "${repoHarnessHerdrSource}" "$out/bin/herdr"
      '';

      # One authoritative Repo Harness source pin is shared by the runtime,
      # projection generators, and flake validation checks.
      repoHarnessRuntimeSource = builtins.fromJSON (builtins.readFile ./repo-harness/runtime-source.json);
      validateSha256Sri = ../../scripts/validate-sha256-sri.py;
      repoHarnessRevision =
        assert repoHarnessRuntimeSource.protocol == 1;
        assert builtins.match "^[0-9a-f]{40}$" repoHarnessRuntimeSource.revision != null;
        repoHarnessRuntimeSource.revision;
      repoHarnessRevisionShort = builtins.substring 0 7 repoHarnessRevision;
      repoHarnessSource =
        assert
          repoHarnessRuntimeSource.source
          == "git+https://github.com/drunkod/repo-harness.git#${repoHarnessRevision}";
        repoHarnessRuntimeSource.source;

      repoHarnessStateRoot = "${config.home.homeDirectory}/.local/share/repo-harness";
      repoHarnessRuntimeRoot = "${repoHarnessStateRoot}/${repoHarnessRevision}";
      repoHarnessGlobalRoot = "${repoHarnessRuntimeRoot}/install/global";
      repoHarnessInstallRoot = "${repoHarnessGlobalRoot}/node_modules/repo-harness";
      repoHarnessCliEntry = "${repoHarnessInstallRoot}/src/cli/index.ts";
      repoHarnessHookEntry = "${repoHarnessInstallRoot}/dist/hook-entry.js";
      repoHarnessGlobalLock = "${repoHarnessGlobalRoot}/bun.lock";

      repoHarnessRuntimeInputs = [
        pkgs.bash
        repoHarnessBun
        pkgs.coreutils
        pkgs.curl
        pkgs.findutils
        pkgs.git
        repoHarnessHerdr
        pkgs.gnugrep
        pkgs.jq
        pkgs.nodejs_24
      ];

      repoHarnessAssertInstalled = ''
        cli_entry=${lib.escapeShellArg repoHarnessCliEntry}
        lock_file=${lib.escapeShellArg repoHarnessGlobalLock}
        expected_revision=${lib.escapeShellArg repoHarnessRevisionShort}

        if [ ! -f "$cli_entry" ] || [ ! -f "$lock_file" ]; then
          echo "repo-harness pinned runtime is not installed; run repo-harness-bootstrap" >&2
          exit 127
        fi
        if ! grep -Fq "repo-harness@github:drunkod/repo-harness#$expected_revision" "$lock_file"; then
          echo "repo-harness runtime revision does not match Nix pin ${repoHarnessRevision}; run repo-harness-bootstrap" >&2
          exit 1
        fi
      '';

      # Install only the exact tested revision into the caller-selected
      # BUN_INSTALL. Callers may provide a package cache and a local Git mirror;
      # the declared package source and resulting lock identity remain the pinned
      # GitHub URL + commit either way.
      repoHarnessInstall = ''
        bun_bin=${lib.escapeShellArg "${repoHarnessBun}/bin/bun"}
        cache_args=()
        if [ -n "''${REPO_HARNESS_BUN_CACHE_DIR:-}" ]; then
          cache_args=(--cache-dir "$REPO_HARNESS_BUN_CACHE_DIR")
        fi

        git_mirror="''${REPO_HARNESS_GIT_MIRROR:-}"
        if [ -n "$git_mirror" ] \
          && git -C "$git_mirror" cat-file -e ${lib.escapeShellArg "${repoHarnessRevision}^{commit}"} 2>/dev/null
        then
          GIT_CONFIG_COUNT=1 \
          GIT_CONFIG_KEY_0="url.file://$git_mirror/.insteadOf" \
          GIT_CONFIG_VALUE_0='https://github.com/drunkod/repo-harness.git' \
            "$bun_bin" add -g "''${cache_args[@]}" ${lib.escapeShellArg repoHarnessSource}
        else
          GIT_CONFIG_COUNT=1 \
          GIT_CONFIG_KEY_0='url.git@github.com:.insteadOf' \
          GIT_CONFIG_VALUE_0='https://github.com/' \
          GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10' \
            "$bun_bin" add -g "''${cache_args[@]}" ${lib.escapeShellArg repoHarnessSource}
        fi

        package_root="$BUN_INSTALL/install/global/node_modules/repo-harness"
        grep -Fq "repo-harness@github:drunkod/repo-harness#${repoHarnessRevisionShort}" \
          "$BUN_INSTALL/install/global/bun.lock" || {
            echo "repo-harness install did not resolve the pinned revision ${repoHarnessRevision}" >&2
            exit 1
          }

        (
          cd "$package_root"
          "$bun_bin" run build:hook-bundle
        )
        [ -f "$package_root/dist/hook-entry.js" ] || {
          echo "repo-harness hook bundle was not produced by the pinned package" >&2
          exit 1
        }
      '';

      repoHarnessAssertTargetPin = ''
        target_runtime_metadata="$nix_config_root/modules/programs/repo-harness/runtime-source.json"
        [ -f "$target_runtime_metadata" ] || {
          echo "Repo Harness runtime metadata is missing: $target_runtime_metadata" >&2
          exit 1
        }

        target_revision="$(jq -er '.revision' "$target_runtime_metadata")"
        target_source="$(jq -er '.source' "$target_runtime_metadata")"
        compiled_revision=${lib.escapeShellArg repoHarnessRevision}
        compiled_source=${lib.escapeShellArg repoHarnessSource}

        if [ "$target_revision" != "$compiled_revision" ] || [ "$target_source" != "$compiled_source" ]; then
          echo "Repo Harness sync executable does not match the target checkout runtime pin." >&2
          echo "  executable revision: $compiled_revision" >&2
          echo "  checkout revision:   $target_revision" >&2
          echo "Build and run the sync executable from the target checkout before writing projections." >&2
          exit 1
        fi
      '';

      repoHarnessLauncher = pkgs.writeShellApplication {
        name = "repo-harness";
        runtimeInputs = [ pkgs.gnugrep ];
        text = ''
          set -euo pipefail
          ${repoHarnessAssertInstalled}
          exec ${lib.escapeShellArg "${repoHarnessBun}/bin/bun"} "$cli_entry" "$@"
        '';
      };

      repoHarnessHookLauncher = pkgs.writeShellApplication {
        name = "repo-harness-hook";
        runtimeInputs = [ pkgs.gnugrep ];
        text = ''
          set -euo pipefail
          ${repoHarnessAssertInstalled}
          hook_entry=${lib.escapeShellArg repoHarnessHookEntry}
          [ -f "$hook_entry" ] || {
            echo "repo-harness hook runtime is missing; run repo-harness-bootstrap" >&2
            exit 127
          }
          exec ${lib.escapeShellArg "${repoHarnessBun}/bin/bun"} "$hook_entry" "$@"
        '';
      };

      repoHarnessBootstrap = pkgs.writeShellApplication {
        name = "repo-harness-bootstrap";
        runtimeInputs = repoHarnessRuntimeInputs;
        text = ''
          set -euo pipefail

          state_root=${lib.escapeShellArg repoHarnessStateRoot}
          final=${lib.escapeShellArg repoHarnessRuntimeRoot}
          lock_dir="$state_root/.install-${repoHarnessRevision}.lock"
          bun_bin=${lib.escapeShellArg "${repoHarnessBun}/bin/bun"}
          stage=""

          validate_release() {
            release="$1"
            cli="$release/install/global/node_modules/repo-harness/src/cli/index.ts"
            hook="$release/install/global/node_modules/repo-harness/dist/hook-entry.js"
            lock="$release/install/global/bun.lock"

            [ -f "$cli" ] && [ -f "$hook" ] && [ -f "$lock" ] || return 1
            grep -Fq "repo-harness@github:drunkod/repo-harness#${repoHarnessRevisionShort}" "$lock" || return 1
            "$bun_bin" "$cli" --version >/dev/null
          }

          mkdir -p "$state_root"

          if [ -e "$final" ]; then
            if validate_release "$final"; then
              echo "Pinned repo-harness revision is already installed and valid:"
              echo "  $final"
              exit 0
            fi

            echo "Existing repo-harness release is incomplete or invalid: $final" >&2
            echo "Refusing to mutate a published revision in place." >&2
            echo "Remove that revision directory deliberately, then rerun repo-harness-bootstrap." >&2
            exit 1
          fi

          if ! mkdir "$lock_dir"; then
            echo "Another repo-harness installation may be active: $lock_dir" >&2
            exit 1
          fi

          cleanup() {
            if [ -n "$stage" ] && [ -e "$stage" ]; then
              rm -rf -- "$stage"
            fi
            rmdir "$lock_dir" 2>/dev/null || true
          }
          trap cleanup EXIT
          trap 'exit 130' INT
          trap 'exit 143' TERM

          # Another installer may have published the revision after our initial
          # pre-lock check but before this process acquired the lock.
          if [ -e "$final" ]; then
            if validate_release "$final"; then
              echo "Pinned repo-harness revision was installed by another process:"
              echo "  $final"
              exit 0
            fi

            echo "A concurrently published repo-harness release is invalid: $final" >&2
            echo "Refusing to overwrite it." >&2
            exit 1
          fi

          stage="$(mktemp -d "$state_root/.install-${repoHarnessRevision}.XXXXXX")"
          export BUN_INSTALL="$stage"
          mkdir -p "$BUN_INSTALL/bin"

          echo "Installing pinned repo-harness revision ${repoHarnessRevision} into staging..."
          ${repoHarnessInstall}

          if ! validate_release "$stage"; then
            echo "Staged repo-harness release failed validation; refusing promotion." >&2
            exit 1
          fi

          mv -- "$stage" "$final"
          stage=""

          if ! validate_release "$final"; then
            echo "Promoted repo-harness release failed post-move validation; removing it." >&2
            rm -rf -- "$final"
            exit 1
          fi

          echo
          echo "repo-harness CLI:"
          "$bun_bin" ${lib.escapeShellArg repoHarnessCliEntry} --version
          echo "revision: ${repoHarnessRevision}"
          echo "runtime: $final"

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
        runtimeInputs = repoHarnessRuntimeInputs ++ [
          pkgs.nix
          pkgs.python3
        ];
        text = ''
                    set -euo pipefail

                    cli=${lib.escapeShellArg (lib.getExe repoHarnessLauncher)}
                    nix_config_root="''${REPO_HARNESS_NIX_CONFIG_ROOT:-$HOME/nix-config}"
                    mode=apply
                    allow_active_codex_fallback=0

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
                        --allow-active-codex-fallback)
                          allow_active_codex_fallback=1
                          shift
                          ;;
                        -h|--help)
                          cat <<'EOF'
          Usage: repo-harness-sync-host-config [--check] [--nix-config <path>] [--allow-active-codex-fallback]

          Generate the current Repo Harness Codex host adapter in an isolated HOME and
          sync its hooks projection into the Nix configuration. Promotion is strict by
          default: hook trust must be derived from the m1-min Codex candidate. The
          fallback flag is diagnostic only. The real ~/.codex files are never mutated.
          EOF
                          exit 0
                          ;;
                        *)
                          echo "unknown argument: $1" >&2
                          exit 2
                          ;;
                      esac
                    done

                    [ -x "$cli" ] || { echo "repo-harness launcher is unavailable" >&2; exit 127; }
                    git -C "$nix_config_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
                      echo "Nix config Git worktree not found: $nix_config_root" >&2
                      exit 1
                    }
                    ${repoHarnessAssertTargetPin}

                    target_dir="$nix_config_root/modules/programs/repo-harness"
                    projection_target="$target_dir/codex-projection.json"
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

                    # Make the Nix-owned adapter bind to the Nix-owned launchers rather
                    # than rediscovering mutable user-bin commands through PATH.
                    python3 - "$generated_hooks" \
                      ${lib.escapeShellArg (lib.getExe repoHarnessHookLauncher)} \
                      ${lib.escapeShellArg (lib.getExe repoHarnessLauncher)} <<'PYHOOKS'
          import json
          import os
          import shlex
          import sys

          path, hook_launcher, cli_launcher = sys.argv[1:4]
          with open(path, encoding="utf-8") as handle:
              payload = json.load(handle)

          hook_needle = "if command -v repo-harness-hook >/dev/null 2>&1; then HOOK_HOST=codex exec repo-harness-hook"
          cli_needle = "command -v repo-harness >/dev/null 2>&1 || exit 0; HOOK_HOST=codex exec repo-harness hook"
          hook_replacement = f"if [ -x {shlex.quote(hook_launcher)} ]; then HOOK_HOST=codex exec {shlex.quote(hook_launcher)}"
          cli_replacement = f"[ -x {shlex.quote(cli_launcher)} ] || exit 0; HOOK_HOST=codex exec {shlex.quote(cli_launcher)} hook"

          managed = 0
          for groups in payload.get("hooks", {}).values():
              for group in groups:
                  for hook in group.get("hooks", []):
                      command = hook.get("command")
                      if not isinstance(command, str) or "repo-harness-managed-hook-v1" not in command:
                          continue
                      managed += 1
                      if command.count(hook_needle) != 1 or command.count(cli_needle) != 1:
                          raise SystemExit(
                              "Repo Harness hook adapter shape changed; expected exactly one "
                              "hook and CLI dispatch fragment per managed hook"
                          )
                      command = command.replace(hook_needle, hook_replacement, 1)
                      command = command.replace(cli_needle, cli_replacement, 1)
                      if command.count(hook_replacement) != 1 or command.count(cli_replacement) != 1:
                          raise SystemExit("Repo Harness hook adapter rewrite was incomplete")
                      hook["command"] = command

          if managed == 0:
              raise SystemExit("Repo Harness generated no managed Codex hooks")

          temporary = path + ".tmp"
          with open(temporary, "w", encoding="utf-8") as handle:
              json.dump(payload, handle, indent=2)
              handle.write("\n")
          os.replace(temporary, path)
          PYHOOKS

                    codex_bin=""
                    codex_source=""
                    used_active_codex_fallback=0
                    candidate_link="$workdir/codex-candidate"
                    if (
                      cd "$nix_config_root"
                      nix build --out-link "$candidate_link" \
                        .#darwinConfigurations.m1-min.pkgs.llm-agents.codex >/dev/null 2>&1
                    ); then
                      candidate_out="$(readlink "$candidate_link" 2>/dev/null || true)"
                      if [ -n "$candidate_out" ] && [ -x "$candidate_out/bin/codex" ]; then
                        codex_bin="$candidate_out/bin/codex"
                        codex_source="Nix candidate"
                      fi
                    fi

                    if [ -z "$codex_bin" ] && [ "$allow_active_codex_fallback" -eq 1 ]; then
                      codex_bin="$(command -v codex || true)"
                      codex_source="active PATH diagnostic fallback"
                      used_active_codex_fallback=1
                    fi
                    if [ -z "$codex_bin" ]; then
                      echo "Unable to build/resolve the m1-min Codex candidate; refusing to derive promotion trust from ambient PATH." >&2
                      echo "Use --allow-active-codex-fallback only for diagnostics, not promotion." >&2
                      exit 1
                    fi
                    echo "Deriving Codex hook trust from $codex_source: $codex_bin"
                    probe_repo="$workdir/probe-repo"
                    mkdir -p "$probe_repo"
                    git -C "$probe_repo" init -q
                    generated_trust="$workdir/codex-hook-trust.json"

                    CODEX_HOME="$generated_home/.codex" python3 - "$codex_bin" "$probe_repo" <<'PYPROBE' > "$generated_trust"
          import json
          import os
          import select
          import subprocess
          import sys
          import time

          codex_bin, probe_repo = sys.argv[1:3]
          process = subprocess.Popen(
              [
                  codex_bin,
                  "-c",
                  f'projects.{json.dumps(probe_repo)}.trust_level="trusted"',
                  "app-server",
                  "--stdio",
              ],
              stdin=subprocess.PIPE,
              stdout=subprocess.PIPE,
              stderr=subprocess.PIPE,
              text=True,
              bufsize=1,
              env=os.environ.copy(),
          )

          def send(payload):
              process.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
              process.stdin.flush()

          def wait_for(request_id, timeout=15):
              deadline = time.time() + timeout
              while time.time() < deadline:
                  readable, _, _ = select.select([process.stdout, process.stderr], [], [], 0.25)
                  for stream in readable:
                      line = stream.readline()
                      if not line:
                          continue
                      if stream is process.stderr:
                          continue
                      try:
                          message = json.loads(line)
                      except json.JSONDecodeError:
                          continue
                      if message.get("id") == request_id:
                          if "error" in message:
                              raise RuntimeError(message["error"])
                          return message
              raise TimeoutError(f"Codex app-server request {request_id} timed out")

          send({
              "method": "initialize",
              "id": 1,
              "params": {
                  "clientInfo": {
                      "name": "repo_harness_nix_sync",
                      "title": "Repo Harness Nix Sync",
                      "version": "1",
                  }
              },
          })
          wait_for(1)
          send({"method": "initialized", "params": {}})
          send({"method": "hooks/list", "id": 2, "params": {"cwds": [probe_repo]}})
          response = wait_for(2)

          trust = {}
          for result in response["result"]["data"]:
              for hook in result["hooks"]:
                  command = hook.get("command") or ""
                  if "repo-harness-managed-hook-v1" not in command:
                      continue
                  source = hook.get("sourcePath") or ""
                  key = hook["key"]
                  prefix = source + ":"
                  if not key.startswith(prefix):
                      raise RuntimeError(f"unexpected hook key/source binding: {key} / {source}")
                  selector = key[len(prefix):]
                  trust[selector] = hook["currentHash"]

          if len(trust) != 12:
              raise RuntimeError(f"expected 12 Repo Harness Codex hooks, found {len(trust)}")

          print(json.dumps(dict(sorted(trust.items())), indent=2))
          process.terminate()
          try:
              process.wait(timeout=5)
          except subprocess.TimeoutExpired:
              process.kill()
          PYPROBE

                    jq -e 'length == 12 and all(.[]; test("^sha256:[0-9a-f]{64}$"))' "$generated_trust" >/dev/null

                    if [ "$used_active_codex_fallback" -eq 1 ]; then
                      echo "Diagnostic probe completed using ambient Codex." >&2
                      echo "This result is not eligible for projection validation or promotion." >&2
                      exit 2
                    fi

                    generated_projection="$workdir/codex-projection.json"
                    jq -n \
                      --arg repo_harness_revision ${lib.escapeShellArg repoHarnessRevision} \
                      --arg repo_harness_source ${lib.escapeShellArg repoHarnessSource} \
                      --arg codex_executable "$codex_bin" \
                      --slurpfile hooks "$generated_hooks" \
                      --slurpfile trust "$generated_trust" \
                      '{
                        protocol: 1,
                        repo_harness: {
                          revision: $repo_harness_revision,
                          source: $repo_harness_source
                        },
                        codex: {
                          executable: $codex_executable
                        },
                        hooks: $hooks[0],
                        trust: $trust[0]
                      }' > "$generated_projection"

                    projection_current=false
                    [ -f "$projection_target" ] && cmp -s "$generated_projection" "$projection_target" && projection_current=true

                    if [ "$projection_current" = true ]; then
                      echo "Repo Harness Codex host projection is current."
                      exit 0
                    fi

                    if [ "$mode" = check ]; then
                      echo "Repo Harness Codex projection is stale or missing: $projection_target" >&2
                      echo "Run: rh-sync-host-config" >&2
                      exit 1
                    fi

                    mkdir -p "$target_dir"
                    tmp_projection="$projection_target.tmp.$$"
                    cp "$generated_projection" "$tmp_projection"
                    mv "$tmp_projection" "$projection_target"

                    echo "Updated Repo Harness Codex host projection:"
                    echo "  $projection_target"
                    echo "  Repo Harness revision: ${repoHarnessRevision}"
                    echo
                    echo "Review and activate it with:"
                    echo "  cd '$nix_config_root'"
                    echo "  git diff -- modules/programs/codex.nix modules/programs/repo-harness.nix modules/programs/repo-harness/codex-projection.json"
                    echo "  sudo darwin-rebuild switch --flake .#m1-min"
                    echo
                    echo "Then restart Codex. Project trust and Repo Harness hook trust are Nix-managed."
        '';
      };

      repoHarnessSyncWaza = pkgs.writeShellApplication {
        name = "repo-harness-sync-waza";
        runtimeInputs = repoHarnessRuntimeInputs ++ [
          pkgs.nix
          pkgs.python3
        ];
        text = ''
                    set -euo pipefail

                    cli=${lib.escapeShellArg (lib.getExe repoHarnessLauncher)}
                    nix_config_root="''${REPO_HARNESS_NIX_CONFIG_ROOT:-$HOME/nix-config}"
                    mode=apply

                    while [ "$#" -gt 0 ]; do
                      case "$1" in
                        --check)
                          mode=check
                          shift
                          ;;
                        --update-check)
                          mode=update-check
                          shift
                          ;;
                        --nix-config)
                          [ "$#" -ge 2 ] || { echo "--nix-config requires a path" >&2; exit 2; }
                          nix_config_root="$2"
                          shift 2
                          ;;
                        -h|--help)
                          cat <<'EOF'
          Usage: repo-harness-sync-waza [--check|--update-check] [--nix-config <path>]

          --check validates the committed pin against the pinned Repo Harness contract
          without consulting upstream HEAD. --update-check performs online update
          discovery without writing. The default mode resolves upstream Waza, validates
          the declared skill/rule paths, and updates the immutable projection metadata.
          The real ~/.agents and ~/.codex trees are never mutated.
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
                    git -C "$nix_config_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
                      echo "Nix config Git worktree not found: $nix_config_root" >&2
                      exit 1
                    }
                    ${repoHarnessAssertTargetPin}

                    target="$nix_config_root/modules/programs/repo-harness/waza-source.json"
                    workdir="$(mktemp -d "''${TMPDIR:-/tmp}/repo-harness-waza-sync.XXXXXX")"
                    trap 'rm -rf "$workdir"' EXIT
                    probe_repo="$workdir/probe-repo"
                    report="$workdir/agent-tooling.json"
                    mkdir -p "$probe_repo"
                    git -C "$probe_repo" init -q

                    (
                      cd "$probe_repo"
                      "$cli" run check-agent-tooling -- --json --host codex > "$report" || true
                    )

                    jq -e '
                      (.tools.waza.source_repo | type == "string" and test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"))
                      and (.tools.waza.source_url | type == "string" and test("^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\\.git)?$"))
                      and (.tools.waza.primary_host == "codex")
                      and (.tools.waza.managed_skills | type == "array" and length > 0 and all(.[]; type == "string" and test("^[A-Za-z0-9_.-]+$")))
                      and (.tools.waza.shared_rules | type == "array" and length > 0 and all(.[]; type == "string" and test("^[A-Za-z0-9_.-]+$")))
                    ' "$report" >/dev/null

                    source_repo="$(jq -r '.tools.waza.source_repo' "$report")"
                    source_url="$(jq -r '.tools.waza.source_url' "$report")"
                    primary_host="$(jq -r '.tools.waza.primary_host' "$report")"
                    managed_skills="$(jq -c '.tools.waza.managed_skills' "$report")"
                    shared_rules="$(jq -c '.tools.waza.shared_rules' "$report")"

                    if [ "$mode" = check ]; then
                      [ -f "$target" ] || {
                        echo "Repo Harness Waza Nix projection is missing: $target" >&2
                        exit 1
                      }
                      jq -e \
                        --arg repo_harness_revision ${lib.escapeShellArg repoHarnessRevision} \
                        --arg source_repo "$source_repo" \
                        --arg source_url "$source_url" \
                        --arg primary_host "$primary_host" \
                        --argjson managed_skills "$managed_skills" \
                        --argjson shared_rules "$shared_rules" \
                        '
                          .protocol == 1
                          and .repo_harness_revision == $repo_harness_revision
                          and .source_repo == $source_repo
                          and .source_url == $source_url
                          and .primary_host == $primary_host
                          and .managed_skills == $managed_skills
                          and .shared_rules == $shared_rules
                          and (.rev | type == "string" and test("^[0-9a-f]{40}$"))
                          and (.hash | type == "string" and startswith("sha256-"))
                        ' "$target" >/dev/null || {
                          echo "Repo Harness Waza pin does not match the pinned runtime contract: $target" >&2
                          echo "Run repo-harness-sync-waza to update deliberately." >&2
                          exit 1
                        }
                      target_hash="$(jq -er '.hash' "$target")"
                      python3 ${validateSha256Sri} "$target_hash" || {
                        echo "Repo Harness Waza pin contains a malformed SHA-256 SRI hash: $target" >&2
                        exit 1
                      }
                      echo "Repo Harness Waza committed pin matches the pinned runtime contract:"
                      echo "  $target"
                      echo "  revision: $(jq -r '.rev' "$target")"
                      exit 0
                    fi

                    rev="$(git ls-remote "$source_url" HEAD | head -n 1 | cut -f 1)"
                    printf '%s' "$rev" | grep -Eq '^[0-9a-f]{40}$' || {
                      echo "Unable to resolve an immutable Waza HEAD from $source_url" >&2
                      exit 1
                    }

                    archive_url="''${source_url%.git}/archive/$rev.tar.gz"
                    prefetch_output="$(nix-prefetch-url --unpack --print-path "$archive_url")"
                    nix_hash="$(printf '%s\n' "$prefetch_output" | head -n 1)"
                    source_path="$(printf '%s\n' "$prefetch_output" | tail -n 1)"
                    sri_hash="$(nix hash to-sri --type sha256 "$nix_hash")"
                    python3 ${validateSha256Sri} "$sri_hash" || {
                      echo "nix hash to-sri produced an invalid SHA-256 SRI hash" >&2
                      exit 1
                    }

                    while IFS= read -r skill; do
                      [ -f "$source_path/skills/$skill/SKILL.md" ] || {
                        echo "Repo Harness declares missing Waza skill at revision $rev: skills/$skill/SKILL.md" >&2
                        exit 1
                      }
                    done < <(printf '%s' "$managed_skills" | jq -r '.[]')

                    while IFS= read -r rule; do
                      [ -f "$source_path/rules/$rule" ] || {
                        echo "Repo Harness declares missing Waza shared rule at revision $rev: rules/$rule" >&2
                        exit 1
                      }
                    done < <(printf '%s' "$shared_rules" | jq -r '.[]')

                    generated="$workdir/waza-source.json"
                    jq -n \
                      --arg repo_harness_revision ${lib.escapeShellArg repoHarnessRevision} \
                      --arg source_repo "$source_repo" \
                      --arg source_url "$source_url" \
                      --arg primary_host "$primary_host" \
                      --arg rev "$rev" \
                      --arg hash "$sri_hash" \
                      --argjson managed_skills "$managed_skills" \
                      --argjson shared_rules "$shared_rules" \
                      '{
                        protocol: 1,
                        repo_harness_revision: $repo_harness_revision,
                        source_repo: $source_repo,
                        source_url: $source_url,
                        primary_host: $primary_host,
                        rev: $rev,
                        hash: $hash,
                        managed_skills: $managed_skills,
                        shared_rules: $shared_rules
                      }' > "$generated"

                    if [ -f "$target" ] && cmp -s "$generated" "$target"; then
                      echo "Repo Harness Waza Nix projection is current: $target"
                      echo "  revision: $rev"
                      exit 0
                    fi

                    if [ "$mode" = update-check ]; then
                      echo "A newer or changed Waza projection is available: $target" >&2
                      echo "  upstream revision: $rev" >&2
                      echo "Run repo-harness-sync-waza to update deliberately." >&2
                      exit 1
                    fi

                    mkdir -p "$(dirname "$target")"
                    tmp_target="$target.tmp.$$"
                    cp "$generated" "$tmp_target"
                    mv "$tmp_target" "$target"

                    echo "Updated Repo Harness Waza Nix projection:"
                    echo "  $target"
                    echo "  revision: $rev"
                    echo "  hash: $sri_hash"
                    echo
                    echo "Review and activate it with:"
                    echo "  cd '$nix_config_root'"
                    echo "  git diff -- modules/programs/codex.nix modules/programs/repo-harness.nix modules/programs/repo-harness/waza-source.json REPO-HARNESS.md"
                    echo "  sudo darwin-rebuild switch --flake .#m1-min"
        '';
      };

      repoHarnessInitCurrent = pkgs.writeShellApplication {
        name = "repo-harness-init-current";
        runtimeInputs = repoHarnessRuntimeInputs;
        text = ''
          set -euo pipefail

          cli=${lib.escapeShellArg (lib.getExe repoHarnessLauncher)}

          echo "Previewing repo-harness initialization for: $PWD"
          "$cli" init --dry-run

          echo
          echo "If the dry run looks correct, apply it with:"
          echo "  repo-harness init"
        '';
      };

      repoHarnessProtectedRuntimeSmoke = pkgs.writeShellApplication {
        name = "repo-harness-protected-runtime-smoke";
        runtimeInputs = repoHarnessRuntimeInputs ++ [
          pkgs.gawk
          pkgs.gnused
          pkgs.python3
        ];
        text = ''
                    set -euo pipefail

                    cli=${lib.escapeShellArg (lib.getExe repoHarnessLauncher)}
                    tmp="$(mktemp -d "''${TMPDIR:-/tmp}/repo-harness-protected-runtime.XXXXXX")"
                    repo="$tmp/repo"
                    worktree="$tmp/worktree"
                    trap 'rm -rf "$tmp"' EXIT

                    mkdir -p "$repo"
                    git -C "$repo" init -q -b main
                    git -C "$repo" config user.name "Repo Harness Smoke"
                    git -C "$repo" config user.email "repo-harness@example.invalid"
                    printf 'base\n' > "$repo/README.md"
                    git -C "$repo" add README.md
                    git -C "$repo" commit -qm base
                    git -C "$repo" worktree add -qb codex/nested-cli-authority "$worktree"

                    mkdir -p \
                      "$worktree/tasks/contracts" \
                      "$worktree/tasks/reviews" \
                      "$worktree/.ai/harness/sprint/claims"
                    printf '# Task Contract: nested CLI authority\n' \
                      > "$worktree/tasks/contracts/nested-cli-authority.contract.md"
                    printf '# Task Review: nested CLI authority\n' \
                      > "$worktree/tasks/reviews/nested-cli-authority.review.md"
                    cat > "$worktree/.ai/harness/sprint/claims/test.claim" <<'EOF'
          claim_id=claim-does-not-exist
          task_id=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
          EOF

                    set +e
                    output="$(cd "$worktree" && "$cli" run contract-worktree finish --no-merge 2>&1)"
                    status=$?
                    set -e

                    [ "$status" -ne 0 ] || {
                      echo "protected runtime smoke unexpectedly published the fabricated claim" >&2
                      exit 1
                    }
                    if printf '%s\n' "$output" | grep -Fq "the repo-harness CLI is unavailable"; then
                      printf '%s\n' "$output" >&2
                      echo "protected runtime smoke reproduced the nested CLI authority bug" >&2
                      exit 1
                    fi
                    printf '%s\n' "$output" | grep -Fq "this worktree no longer owns the sprint lease it claimed" || {
                      printf '%s\n' "$output" >&2
                      echo "protected runtime smoke did not reach Sprint lease verification" >&2
                      exit 1
                    }

                    closeout_integration=${lib.escapeShellArg ../../scripts/repo-harness-protected-closeout-smoke.sh}
                    bash "$closeout_integration" "$cli"

                    package_root=${lib.escapeShellArg repoHarnessInstallRoot}
                    positive_test="$package_root/tests/contract-worktree-closeout-journal.test.ts"
                    [ -f "$positive_test" ] || {
                      echo "pinned runtime is missing its positive closeout regression test: $positive_test" >&2
                      exit 1
                    }

                    set +e
                    positive_output="$(
                      cd "$package_root"
                      ${lib.escapeShellArg "${repoHarnessBun}/bin/bun"} test \
                        "$positive_test" \
                        --test-name-pattern \
                        "an uninterrupted finish journals every phase and clears its snapshot on completion" \
                        2>&1
                    )"
                    positive_status=$?
                    set -e
                    printf '%s\n' "$positive_output"

                    if [ "$positive_status" -ne 0 ]; then
                      echo "pinned runtime direct-helper journal regression failed" >&2
                      exit 1
                    fi
                    printf '%s\n' "$positive_output" | grep -Eq '^[[:space:]]*[1-9][0-9]* pass([[:space:]]|$)' || {
                      echo "pinned runtime direct-helper journal regression executed zero tests" >&2
                      exit 1
                    }

                    echo "Repo Harness protected runtime smoke passed."
                    echo "  negative protected Sprint authority: passed"
                    echo "  positive protected Sprint closeout integration: passed"
                    echo "  positive direct-helper journal regression: passed"
                    echo "  revision: ${repoHarnessRevision}"
        '';
      };

      repoHarnessCheck = pkgs.writeShellApplication {
        name = "repo-harness-check";
        runtimeInputs = repoHarnessRuntimeInputs;
        text = ''
          set -euo pipefail

          cli=${lib.escapeShellArg (lib.getExe repoHarnessLauncher)}
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
          repoHarnessHookLauncher
          repoHarnessBootstrap
          repoHarnessGenerateHostConfig
          repoHarnessSyncHostConfig
          repoHarnessSyncWaza
          repoHarnessInitCurrent
          repoHarnessProtectedRuntimeSmoke
          repoHarnessCheck
        ];

        shellAliases = {
          rh-bootstrap = "repo-harness-bootstrap";
          rh-generate-host-config = "repo-harness-generate-host-config";
          rh-sync-host-config = "repo-harness-sync-host-config";
          rh-sync-waza = "repo-harness-sync-waza";
          rh-init = "repo-harness-init-current";
          rh-smoke = "repo-harness-protected-runtime-smoke";
          rh-check = "repo-harness-check";
        };
      };
    };
}
