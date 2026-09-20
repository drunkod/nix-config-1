{
  pkgs,
  targetHomePackages ? null,
}:
let
  lib = pkgs.lib;
  projection = ../modules/programs/repo-harness/codex-projection.json;
  runtimeMetadata = ../modules/programs/repo-harness/runtime-source.json;
  waza = ../modules/programs/repo-harness/waza-source.json;
  validateSha256Sri = ../scripts/validate-sha256-sri.py;

  targetPackage =
    name:
    let
      matches = builtins.filter (package: (package.name or "") == name) (
        if targetHomePackages == null then [ ] else targetHomePackages
      );
    in
    assert builtins.length matches == 1;
    builtins.head matches;

  targetRepoHarnessLauncher =
    if targetHomePackages == null then null else targetPackage "repo-harness";
  targetRepoHarnessHookLauncher =
    if targetHomePackages == null then null else targetPackage "repo-harness-hook";

  schemaCheck =
    pkgs.runCommand "repo-harness-projection-schema-check"
      {
        nativeBuildInputs = [
          pkgs.jq
          pkgs.python3
        ];
      }
      ''
        set -euo pipefail

        projection=${projection}
        runtime_metadata=${runtimeMetadata}
        waza=${waza}

        jq -e --slurpfile runtime "$runtime_metadata" --slurpfile waza "$waza" '
          def selector_name($event):
            if $event == "SessionStart" then "session_start"
            elif $event == "PreToolUse" then "pre_tool_use"
            elif $event == "PostToolUse" then "post_tool_use"
            elif $event == "UserPromptSubmit" then "user_prompt_submit"
            elif $event == "SubagentStart" then "subagent_start"
            elif $event == "SubagentStop" then "subagent_stop"
            elif $event == "Stop" then "stop"
            else ""
            end;

          def managed_entries:
            [
              .hooks.hooks
              | to_entries[] as $event
              | $event.value
              | to_entries[] as $group
              | $group.value.hooks
              | to_entries[]
              | select(
                  ((.value.command | type) == "string")
                  and (.value.command | contains("repo-harness-managed-hook-v1"))
                )
              | {
                  event: $event.key,
                  group: $group.key,
                  hook: .key,
                  value: .value
                }
            ];

          def derived_selectors:
            [
              managed_entries[]
              | (
                  selector_name(.event)
                  + ":"
                  + (.group | tostring)
                  + ":"
                  + (.hook | tostring)
                )
            ]
            | sort;

          . as $projection
          | $runtime[0] as $runtime
          | $waza[0] as $waza
          | $runtime.protocol == 1
          and ($runtime.revision | test("^[0-9a-f]{40}$"))
          and ($runtime.source == ("git+https://github.com/drunkod/repo-harness.git#" + $runtime.revision))
          and $projection.protocol == 1
          and ($projection.repo_harness.revision == $runtime.revision)
          and ($projection.repo_harness.source == $runtime.source)
          and ($projection.codex.executable | type == "string")
          and ($projection.codex.executable | test("^/nix/store/[a-z0-9]+-codex-[^/]+/bin/codex$"))
          and ($projection.hooks.hooks | type == "object")
          and ((managed_entries | length) == 12)
          and all(
            managed_entries[];
            (selector_name(.event) != "")
            and (.value.type == "command")
            and ((.value.timeout | type) == "number")
            and (.value.command | test("/nix/store/[a-z0-9]+-repo-harness-hook/bin/repo-harness-hook"))
            and (.value.command | test("/nix/store/[a-z0-9]+-repo-harness/bin/repo-harness"))
          )
          and (($projection.trust | type) == "object")
          and (($projection.trust | length) == (managed_entries | length))
          and all($projection.trust[]; test("^sha256:[0-9a-f]{64}$"))
          and (($projection.trust | keys | sort) == derived_selectors)
          and $waza.protocol == 1
          and ($waza.repo_harness_revision == $runtime.revision)
          and ($waza.source_repo | test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"))
          and ($waza.rev | test("^[0-9a-f]{40}$"))
          and ($waza.hash | startswith("sha256-"))
          and ($waza.managed_skills | length > 0)
          and ($waza.shared_rules | length > 0)
        ' "$projection" >/dev/null

        waza_hash="$(jq -er '.hash' "$waza")"
        python3 ${validateSha256Sri} "$waza_hash"

        touch "$out"
      '';

  m1MinProjectionCheck =
    pkgs.runCommand "repo-harness-m1-min-projection-check"
      {
        nativeBuildInputs = [
          pkgs.git
          pkgs.jq
          pkgs.python3
        ];
      }
      ''
        set -euo pipefail

        projection=${projection}
        expected_codex=${pkgs.llm-agents.codex}/bin/codex
        expected_cli=${targetRepoHarnessLauncher}/bin/repo-harness
        expected_hook=${targetRepoHarnessHookLauncher}/bin/repo-harness-hook

        jq -e --arg expected_codex "$expected_codex" '
          .codex.executable == $expected_codex
        ' "$projection" >/dev/null

        python3 - "$projection" "$expected_cli" "$expected_hook" <<'PYLAUNCHERS'
        import json
        import re
        import sys

        projection_path, expected_cli, expected_hook = sys.argv[1:4]
        with open(projection_path, encoding="utf-8") as handle:
            projection = json.load(handle)

        cli_pattern = re.compile(r"/nix/store/[a-z0-9]+-repo-harness/bin/repo-harness")
        hook_pattern = re.compile(r"/nix/store/[a-z0-9]+-repo-harness-hook/bin/repo-harness-hook")

        managed = []
        for groups in projection.get("hooks", {}).get("hooks", {}).values():
            for group in groups:
                for hook in group.get("hooks", []):
                    command = hook.get("command")
                    if isinstance(command, str) and "repo-harness-managed-hook-v1" in command:
                        managed.append(command)

        if not managed:
            raise SystemExit("projection contains no managed Repo Harness hooks")

        for command in managed:
            cli_paths = sorted(set(cli_pattern.findall(command)))
            hook_paths = sorted(set(hook_pattern.findall(command)))
            if cli_paths != [expected_cli]:
                raise SystemExit(
                    f"projected Repo Harness CLI launcher mismatch: expected {expected_cli}, found {cli_paths}"
                )
            if hook_paths != [expected_hook]:
                raise SystemExit(
                    f"projected Repo Harness hook launcher mismatch: expected {expected_hook}, found {hook_paths}"
                )
        PYLAUNCHERS

        codex_home="$TMPDIR/codex-home"
        probe_repo="$TMPDIR/probe-repo"
        projected_trust="$TMPDIR/projected-trust.json"
        actual_trust="$TMPDIR/actual-trust.json"
        mkdir -p "$codex_home" "$probe_repo"
        git -C "$probe_repo" init -q

        jq '.hooks' "$projection" > "$codex_home/hooks.json"
        printf '%s\n' 'default_mode_request_user_input = true' > "$codex_home/config.toml"
        jq -S '.trust' "$projection" > "$projected_trust"

        CODEX_HOME="$codex_home" python3 - "$expected_codex" "$probe_repo" <<'PYPROBE' > "$actual_trust"
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
            stderr_lines = []
            while time.time() < deadline:
                readable, _, _ = select.select([process.stdout, process.stderr], [], [], 0.25)
                for stream in readable:
                    line = stream.readline()
                    if not line:
                        continue
                    if stream is process.stderr:
                        stderr_lines.append(line.rstrip())
                        continue
                    try:
                        message = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if message.get("id") == request_id:
                        if "error" in message:
                            raise RuntimeError(message["error"])
                        return message
            detail = "\n".join(stderr_lines[-20:])
            raise TimeoutError(
                f"Codex app-server request {request_id} timed out"
                + (f"\n{detail}" if detail else "")
            )

        try:
            send(
                {
                    "method": "initialize",
                    "id": 1,
                    "params": {
                        "clientInfo": {
                            "name": "repo_harness_nix_check",
                            "title": "Repo Harness Nix Check",
                            "version": "1",
                        }
                    },
                }
            )
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
                        raise RuntimeError(
                            f"unexpected hook key/source binding: {key} / {source}"
                        )
                    trust[key[len(prefix):]] = hook["currentHash"]

            print(json.dumps(dict(sorted(trust.items())), indent=2))
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        PYPROBE

        jq -S '.' "$actual_trust" > "$actual_trust.sorted"
        if ! cmp -s "$projected_trust" "$actual_trust.sorted"; then
          echo "Projected hook approvals do not match the selected m1-min Codex and emitted hook configuration." >&2
          diff -u "$projected_trust" "$actual_trust.sorted" >&2 || true
          exit 1
        fi

        touch "$out"
      '';
in
{
  repo-harness-mcp-scripts =
    pkgs.runCommand "repo-harness-mcp-scripts-check"
      {
        nativeBuildInputs = with pkgs; [
          bash
          shellcheck
        ];
      }
      ''
        set -euo pipefail
        cd ${../scripts/repo-harness-mcp}

        for script in *.sh; do
          echo "checking $script"
          bash -n "$script"
          shellcheck -x "$script"
        done

        touch "$out"
      '';

  repo-harness-projection-schema = schemaCheck;
}
// lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") {
  repo-harness-m1-min-projection = m1MinProjectionCheck;
}
