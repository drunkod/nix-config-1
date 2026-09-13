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
        runtimeInputs = repoHarnessRuntimeInputs ++ [ pkgs.python3 ];
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
          trust_target="$target_dir/codex-hook-trust.json"
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

          codex_bin=""
          codex_source=""
          if command -v nix >/dev/null 2>&1 && [ -f "$nix_config_root/flake.nix" ]; then
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
          fi
          if [ -z "$codex_bin" ]; then
            codex_bin="$(command -v codex || true)"
            codex_source="active PATH"
          fi
          [ -n "$codex_bin" ] || { echo "Codex CLI is required to derive hook trust hashes" >&2; exit 127; }
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

          hooks_current=false
          trust_current=false
          [ -f "$target" ] && cmp -s "$generated_hooks" "$target" && hooks_current=true
          [ -f "$trust_target" ] && cmp -s "$generated_trust" "$trust_target" && trust_current=true

          if [ "$hooks_current" = true ] && [ "$trust_current" = true ]; then
            echo "Repo Harness Codex host projection and trust hashes are current."
            exit 0
          fi

          if [ "$mode" = check ]; then
            [ "$hooks_current" = true ] || echo "Repo Harness Codex hook projection is stale or missing: $target" >&2
            [ "$trust_current" = true ] || echo "Repo Harness Codex hook trust projection is stale or missing: $trust_target" >&2
            echo "Run: rh-sync-host-config" >&2
            exit 1
          fi

          mkdir -p "$target_dir"
          tmp_target="$target.tmp.$$"
          tmp_trust_target="$trust_target.tmp.$$"
          cp "$generated_hooks" "$tmp_target"
          cp "$generated_trust" "$tmp_trust_target"
          mv "$tmp_target" "$target"
          mv "$tmp_trust_target" "$trust_target"

          echo "Updated Repo Harness Codex host projections:"
          echo "  $target"
          echo "  $trust_target"
          echo
          echo "Review and activate it with:"
          echo "  cd '$nix_config_root'"
          echo "  git diff -- modules/programs/codex.nix modules/programs/repo-harness.nix modules/programs/repo-harness/codex-hooks.json modules/programs/repo-harness/codex-hook-trust.json"
          echo "  sudo darwin-rebuild switch --flake .#m1-min"
          echo
          echo "Then restart Codex. Project trust and Repo Harness hook trust are Nix-managed."
        '';
      };

      repoHarnessSyncWaza = pkgs.writeShellApplication {
        name = "repo-harness-sync-waza";
        runtimeInputs = repoHarnessRuntimeInputs ++ [ pkgs.nix ];
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
Usage: repo-harness-sync-waza [--check] [--nix-config <path>]

Read the Waza contract from the installed Repo Harness runtime, resolve the
current upstream Waza revision, prefetch it through Nix, validate every managed
skill/shared-rule path, and sync the immutable projection metadata into
nix-config. The real ~/.agents and ~/.codex trees are never mutated.
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
            (.tools.waza.source_repo | type == "string" and test("^[^/]+/[^/]+$"))
            and (.tools.waza.source_url | type == "string" and startswith("https://github.com/"))
            and (.tools.waza.primary_host == "codex")
            and (.tools.waza.managed_skills | type == "array" and length > 0 and all(.[]; type == "string" and length > 0))
            and (.tools.waza.shared_rules | type == "array" and length > 0 and all(.[]; type == "string" and length > 0))
          ' "$report" >/dev/null

          source_repo="$(jq -r '.tools.waza.source_repo' "$report")"
          source_url="$(jq -r '.tools.waza.source_url' "$report")"
          primary_host="$(jq -r '.tools.waza.primary_host' "$report")"
          managed_skills="$(jq -c '.tools.waza.managed_skills' "$report")"
          shared_rules="$(jq -c '.tools.waza.shared_rules' "$report")"

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
            --arg source_repo "$source_repo" \
            --arg source_url "$source_url" \
            --arg primary_host "$primary_host" \
            --arg rev "$rev" \
            --arg hash "$sri_hash" \
            --argjson managed_skills "$managed_skills" \
            --argjson shared_rules "$shared_rules" \
            '{
              protocol: 1,
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

          if [ "$mode" = check ]; then
            echo "Repo Harness Waza Nix projection is stale or missing: $target" >&2
            echo "  upstream revision: $rev" >&2
            echo "Run: rh-sync-waza" >&2
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
          repoHarnessSyncWaza
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
          rh-sync-waza = "repo-harness-sync-waza";
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
