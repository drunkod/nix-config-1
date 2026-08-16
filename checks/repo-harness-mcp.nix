{ pkgs }:
{
  repo-harness-mcp-scripts = pkgs.runCommand "repo-harness-mcp-scripts-check" {
    nativeBuildInputs = with pkgs; [
      bash
      shellcheck
    ];
  } ''
    set -euo pipefail
    cd ${../scripts/repo-harness-mcp}

    for script in *.sh; do
      echo "checking $script"
      bash -n "$script"
      shellcheck -x "$script"
    done

    touch "$out"
  '';
}
