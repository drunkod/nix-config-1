#!/bin/bash
set -euo pipefail

cli="${1:-}"
if [[ -z "$cli" || ! -x "$cli" ]]; then
  echo "usage: repo-harness-protected-closeout-smoke.sh <repo-harness-cli>" >&2
  exit 2
fi

# The integration must prove that the protected public runner supplies these
# authorities. Never inherit a test-provided substitute for them.
unset REPO_HARNESS_BASH_BIN
unset REPO_HARNESS_BUN_BIN
unset REPO_HARNESS_CLI_BIN
unset REPO_HARNESS_GIT_BIN
unset REPO_HARNESS_HELPER_SOURCE_PATH
unset REPO_HARNESS_HOOK_CLI
unset REPO_HARNESS_SOURCE_ROOT
unset REPO_HARNESS_TARGET_REPO_ROOT
unset REPO_HARNESS_WORKFLOW_STATE_LIB

tmp="$(mktemp -d "${TMPDIR:-/tmp}/repo-harness-protected-closeout.XXXXXX")"
tmp="$(cd "$tmp" && pwd -P)"
repo="$tmp/repo"
worktree="$tmp/worktree"
gate_dir=""

cleanup() {
  if [[ -n "$gate_dir" ]]; then
    case "$gate_dir" in
      */.repo-harness/gates/*) rm -rf "$gate_dir" ;;
      *) echo "refusing unsafe acceptance-gate cleanup: $gate_dir" >&2 ;;
    esac
  fi
  rm -rf "$tmp"
}
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
plan="$(printf '%s\n' "$start_output" | sed -nE 's/^Captured plan: (.+)$/\1/p' | head -1)"
claim_id="$(printf '%s\n' "$start_output" | sed -nE 's/^Claimed backlog task .* as claim ([^ ]+)$/\1/p' | head -1)"

task="$(printf '%s\n' "$start_output" | sed -nE "s/^Claimed backlog task '([^']+)'.*$/\1/p" | head -1)"
for required in plan claim_id task; do
  eval "value=\${$required}"
  if [[ -z "$value" ]]; then
    printf '%s\n' "$start_output" >&2
    echo "protected closeout smoke could not resolve $required from start-task" >&2
    exit 1
  fi
done

identity="$("$cli" sprint identify \
  --task "$task" \
  --target-ref main \
  --sprint-path "$sprint")"
task_id="$(printf '%s' "$identity" | jq -r '.task_id // empty')"
if [[ ! "$task_id" =~ ^[0-9a-f]{64}$ ]]; then
  echo "protected closeout smoke received invalid task id: $task_id" >&2
  exit 1
fi

git add -A
git commit -qm "prepare protected closeout fixture"
git worktree add -qb codex/protected-closeout-smoke "$worktree"
worktree="$(cd "$worktree" && pwd -P)"

"$cli" sprint bind \
  --claim-id "$claim_id" \
  --worktree "$worktree" \
  --branch codex/protected-closeout-smoke \
  --unit-ref "$plan" >/dev/null

"$cli" sprint write-claim-token \
  --task-id "$task_id" \
  --claim-id "$claim_id" \
  --worktree "$worktree" \
  --sprint-path "$sprint" \
  --task "$task" \
  --unit-ref "$plan" >/dev/null

cd "$worktree"
"$cli" run switch-plan --plan "$plan" >/dev/null

contract="$(sed -nE 's/^> \*\*Task Contract\*\*: `?([^`]+)`?$/\1/p' "$plan" | head -1)"
review="$(sed -nE 's/^> \*\*Task Review\*\*: `?([^`]+)`?$/\1/p' "$plan" | head -1)"
notes="$(sed -nE 's/^> \*\*Implementation Notes\*\*: `?([^`]+)`?$/\1/p' "$plan" | head -1)"
for artifact in "$contract" "$review" "$notes"; do
  if [[ -z "$artifact" || ! -f "$artifact" ]]; then
    echo "protected closeout smoke is missing generated artifact: $artifact" >&2
    exit 1
  fi
done

printf 'protected closeout smoke\n' >> README.md

python3 - "$plan" "$contract" "$notes" <<'PYCONTRACT'
from pathlib import Path
import json
import re
import sys

plan_path, contract_path, notes_path = map(Path, sys.argv[1:4])
plan = plan_path.read_text().replace("- [ ]", "- [x]")
plan_path.write_text(plan)

contract = contract_path.read_text()
contract = re.sub(
    r"^> \*\*Status\*\*: .+$",
    "> **Status**: Fulfilled",
    contract,
    count=1,
    flags=re.M,
)
contract = re.sub(
    r"^> \*\*Task Profile\*\*: .+$",
    "> **Task Profile**: docs-only",
    contract,
    count=1,
    flags=re.M,
)

def replace_section(text: str, heading: str, body: str) -> str:
    pattern = rf"(^## {re.escape(heading)}\n)(.*?)(?=^## |\Z)"
    updated, count = re.subn(
        pattern,
        rf"\1\n{body.rstrip()}\n\n",
        text,
        count=1,
        flags=re.M | re.S,
    )
    if count != 1:
        raise SystemExit(f"generated contract is missing section: {heading}")
    return updated

contract = replace_section(
    contract,
    "Why",
    "This fixture proves the installed protected Repo Harness runner can close a valid claimed Sprint worktree.",
)

contract = replace_section(
    contract,
    "Goal",
    "Append one deterministic smoke line to README.md and close the claimed Sprint worktree through the public protected runner.",
)
contract = replace_section(
    contract,
    "Scope",
    "- In scope: README.md plus Repo Harness lifecycle artifacts under plans/ and tasks/.\n"
    "- Out of scope: product code and host configuration.\n"
    "- Taste constraints: keep the fixture deterministic and offline.",
)
contract = replace_section(
    contract,
    "Falsifier",
    "The protected closeout is invalid if verification, acceptance, lease ownership, or lifecycle publication fails.",
)
contract = replace_section(
    contract,
    "Allowed Paths",
    """```yaml
allowed_paths:
  - README.md
  - plans/
  - tasks/
```""",
)
contract = replace_section(
    contract,
    "Exit Criteria (Machine Verifiable)",
    f"""```yaml
exit_criteria:
  files_exist:
    - README.md
    - {notes_path.as_posix()}
  artifacts_exist: []
```""",
)

verification = {
    "protocol": 1,
    "checks": [{
        "id": "smoke-diff-check",
        "kind": "command",
        "command": "git diff --check main...HEAD",
        "cwd": ".",
        "phase": "verification",
        "cost": "normal",
        "evidence_policy": "current_exact",
        "necessity": "Proves the committed protected-closeout fixture diff has no whitespace errors.",
        "inputs": {"env": []},
    }],
}
contract = replace_section(
    contract,
    "Verification Plan",
    "```json\n" + json.dumps(verification, indent=2) + "\n```",
)
contract_path.write_text(contract)

with notes_path.open("a") as handle:
    handle.write(
        "\n## Protected Closeout Smoke\n\n"
        "- Deterministic README-only fixture executed through the installed protected runner.\n"
    )
PYCONTRACT

git add README.md "$plan" "$contract" "$notes"
git commit -qm "implement protected closeout smoke"

"$cli" run contract-run preflight --contract "$contract" >/dev/null

acceptance_path="$("$cli" run acceptance-receipt path)"
gate_dir="$(dirname "$acceptance_path")"
case "$gate_dir" in
  */.repo-harness/gates/*) ;;
  *)
    echo "protected closeout smoke received unsafe acceptance path: $acceptance_path" >&2
    exit 1
    ;;
esac

prepare_output="$("$cli" run verify-sprint \
  --prepare-acceptance \
  --contract "$contract" 2>&1)"
printf '%s\n' "$prepare_output" | grep -Fq "[PASS] check passed" || {
  printf '%s\n' "$prepare_output" >&2
  echo "protected closeout smoke did not execute the real verification command" >&2
  exit 1
}
printf '%s\n' "$prepare_output" | grep -Fq "Sprint verification passed" || {
  printf '%s\n' "$prepare_output" >&2
  echo "protected closeout smoke did not produce passing prepared evidence" >&2
  exit 1
}
jq -e '
  .status == "pass"
  and .exit_code == 0
  and .acceptance_receipt.status == "pending"
' .ai/harness/checks/latest.json >/dev/null

owner="$(sed -nE 's/^> \*\*Owner\*\*:[[:space:]]*(.+)$/\1/p' "$contract" | head -1)"

if [[ -z "$owner" ]]; then
  echo "protected closeout smoke could not resolve the contract owner" >&2
  exit 1
fi

"$cli" run acceptance-receipt grant-waiver \
  --contract "$contract" \
  --actor "$owner" \
  --summary "Deterministic local integration fixture; no external reviewer is required." \
  >/dev/null

"$cli" run acceptance-receipt record \
  --disposition user_waiver \
  --contract "$contract" \
  --verification .ai/harness/checks/latest.json \
  >/dev/null

final_verify_output="$("$cli" run verify-sprint --contract "$contract" 2>&1)"
printf '%s\n' "$final_verify_output" | grep -Fq "Sprint acceptance finalized without rerunning verification" || {
  printf '%s\n' "$final_verify_output" >&2
  echo "protected closeout smoke did not finalize the real AcceptanceReceipt" >&2
  exit 1
}
grep -Fq '> **Status**: Accepted' "$review"
grep -Fq '> **Recommendation**: pass' "$review"

finish_output="$("$cli" run contract-worktree finish --no-merge 2>&1)"
printf '%s\n' "$finish_output" | grep -Fq "Sprint lease verified for claim $claim_id" || {
  printf '%s\n' "$finish_output" >&2
  echo "protected closeout smoke did not verify the real Sprint lease" >&2
  exit 1
}

printf '%s\n' "$finish_output" | grep -Fq "[ArchitectureSync]" || {
  printf '%s\n' "$finish_output" >&2
  echo "protected closeout smoke did not run the real architecture gate" >&2
  exit 1
}
printf '%s\n' "$finish_output" | grep -Fq "Sprint acceptance already finalized" || {
  printf '%s\n' "$finish_output" >&2
  echo "protected closeout smoke did not re-check receipt-bound verification" >&2
  exit 1
}
printf '%s\n' "$finish_output" | grep -Fq "Merge skipped by --no-merge." || {
  printf '%s\n' "$finish_output" >&2
  echo "protected closeout smoke did not complete lifecycle publication" >&2
  exit 1
}

archived_plan="plans/archive/$(basename "$plan")"
[[ -f "$archived_plan" ]] || {
  echo "protected closeout smoke did not archive the completed plan" >&2
  exit 1
}
awk -F '|' -v task="$task" '
  $0 ~ "^\\|" && index($0, task) {
    status = $4
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
    if (status == "[x]") found = 1
  }
  END { exit found ? 0 : 1 }
' "$sprint" || {
  echo "protected closeout smoke did not complete the Sprint row" >&2
  exit 1
}

common_dir="$(git rev-parse --git-common-dir)"
journal_status="$(find "$common_dir/repo-harness/transactions/finish" \
  -name status.json -type f -print -quit 2>/dev/null || true)"
[[ -n "$journal_status" ]] || {
  echo "protected closeout smoke produced no finish journal" >&2
  exit 1
}
jq -e '
  .status == "complete"
  and ([.phases[].phase] == [
    "prepared",
    "implementation_committed",
    "lifecycle_applied",
    "lifecycle_committed",
    "complete"
  ])
' "$journal_status" >/dev/null

lease_owner="$common_dir/repo-harness/coordination/v1/leases/$task_id/owner.json"
jq -e \
  --arg claim_id "$claim_id" \
  '
    .claim_id == $claim_id
    and .state == "completing"
    and (.finish_transaction_key | type == "string" and test("^[0-9a-f]{40}$"))
  ' "$lease_owner" >/dev/null

if [[ -n "$(git status --short)" ]]; then
  git status --short >&2
  echo "protected closeout smoke left tracked worktree changes" >&2
  exit 1
fi

echo "Repo Harness positive protected closeout integration passed."
echo "  task id: $task_id"
echo "  claim id: $claim_id"
echo "  journal: complete"
