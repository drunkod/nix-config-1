#!/bin/bash
set -euo pipefail

cli="${1:-}"
if [[ -z "$cli" || ! -x "$cli" ]]; then
  echo "usage: repo-harness-protected-closeout-smoke.sh <repo-harness-cli>" >&2
  exit 2
fi

# Protected execution must receive authority from the public runner.
unset REPO_HARNESS_BASH_BIN REPO_HARNESS_BUN_BIN REPO_HARNESS_CLI_BIN
unset REPO_HARNESS_GIT_BIN REPO_HARNESS_HELPER_SOURCE_PATH
unset REPO_HARNESS_HOOK_CLI REPO_HARNESS_SOURCE_ROOT
unset REPO_HARNESS_TARGET_REPO_ROOT REPO_HARNESS_WORKFLOW_STATE_LIB

tmp="$(mktemp -d "${TMPDIR:-/tmp}/repo-harness-protected-closeout.XXXXXX")"
tmp="$(cd "$tmp" && pwd -P)"
repo="$tmp/repo"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" config user.name "Repo Harness Protected Smoke"
git -C "$repo" config user.email "repo-harness-smoke@example.invalid"
printf '# protected closeout smoke\n' > "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -qm base

"$cli" init \
  --repo "$repo" \
  --target codex \
  --mode standard \
  --no-codegraph \
  --no-verify \
  --json >/dev/null
git -C "$repo" add -A
git -C "$repo" commit -qm "initialize Repo Harness fixture"

cd "$repo"
"$cli" run sprint-backlog init \
  --slug protected-closeout-smoke \
  --title "Protected closeout smoke" >/dev/null
sprint="$(cat .ai/harness/sprint/active-sprint)"

python3 - "$sprint" <<'PYSPRINT'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
if "> **Status**: Draft" not in source:
    raise SystemExit("generated Sprint is not Draft")
path.write_text(source.replace("> **Status**: Draft", "> **Status**: Approved", 1))
PYSPRINT

git add "$sprint"
git commit -qm "approve protected closeout Sprint"

start_output="$("$cli" run sprint-backlog start-task \
  --task 1 \
  --execute \
  --sprint "$sprint")"
printf '%s\n' "$start_output"

plan="$(printf '%s\n' "$start_output" | sed -nE 's/^Captured plan: (.+)$/\1/p' | head -1)"
claim_id="$(printf '%s\n' "$start_output" | sed -nE 's/^Claimed backlog task .* as claim ([^ ]+)$/\1/p' | head -1)"
worktree="$(printf '%s\n' "$start_output" | sed -nE 's/^\[ContractWorktree\] (Created worktree|Added worktree for existing branch|Reusing existing worktree): (.+)$/\2/p' | tail -1)"
branch="$(printf '%s\n' "$start_output" | sed -nE 's/^\[ContractWorktree\] Branch: (.+)$/\1/p' | tail -1)"

for required in plan claim_id worktree branch; do
  eval "value=\${$required}"
  if [[ -z "$value" ]]; then
    echo "protected closeout smoke could not resolve $required from start-task" >&2
    exit 1
  fi
done

case "$worktree" in
  "$tmp"/*) ;;
  *) echo "protected closeout smoke received worktree outside fixture: $worktree" >&2; exit 1 ;;
esac

[[ -f "$worktree/$plan" ]] || {
  echo "protected closeout smoke is missing slim plan: $worktree/$plan" >&2
  exit 1
}

for heading in Goal Scope Verify Rollback; do
  grep -Fq "## $heading" "$worktree/$plan" || {
    echo "protected closeout smoke plan is missing ## $heading" >&2
    exit 1
  }
done
if grep -Fq '**Task Contract**' "$worktree/$plan"; then
  echo "protected closeout smoke unexpectedly recreated retired contract artifacts" >&2
  exit 1
fi

claims_dir="$worktree/.ai/harness/sprint/claims"
claim_count="$(find "$claims_dir" -maxdepth 1 -type f -name '*.claim' -print | wc -l | tr -d '[:space:]')"
[[ "$claim_count" == "1" ]] || {
  echo "protected closeout smoke expected exactly one worktree claim token" >&2
  exit 1
}
claim_token="$(find "$claims_dir" -maxdepth 1 -type f -name '*.claim' -print -quit)"
grep -Fxq "claim_id=$claim_id" "$claim_token" || {
  echo "protected closeout smoke claim token does not match the Sprint claim" >&2
  exit 1
}
grep -Fxq "unit_ref=$plan" "$claim_token" || {
  echo "protected closeout smoke claim token does not bind the slim plan" >&2
  exit 1
}

cd "$worktree"
printf 'protected closeout smoke\n' >> README.md

finish_output="$("$cli" run contract-worktree finish --no-merge 2>&1)"
printf '%s\n' "$finish_output"

printf '%s\n' "$finish_output" | grep -Fq "Sprint lease verified for claim $claim_id" || {
  echo "protected closeout smoke did not reach Sprint lease verification" >&2
  exit 1
}
printf '%s\n' "$finish_output" | grep -Fq "Candidate committed; no main merge or additional verification was performed." || {
  echo "protected closeout smoke did not commit the 0.20 candidate" >&2
  exit 1
}
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] || {
  echo "protected closeout smoke left the candidate worktree dirty" >&2
  git status --short >&2
  exit 1
}
grep -Fq "protected closeout smoke" README.md

echo "Repo Harness protected closeout smoke passed."
echo "  slim Sprint plan capture: passed"
echo "  bound worktree claim token: passed"
echo "  protected Sprint lease verification: passed"
echo "  no-merge candidate commit: passed"
