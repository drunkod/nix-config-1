# Repo-harness ChatGPT Browser Create pre-tutorial

> Historical specialist test notes for the optional Browser Create workflow. This is not the normal Coding MCP onboarding path. Start with [guide 1: onboard a repository](../guides/01-onboard-repository.md). Shared rules: [`Repo Harness safety`](../safety.md).

This pre-tutorial records the working setup sequence and the failure modes found during the first isolated `browser-create` smoke-test preparation on macOS.

Use it before the full workflow in the [Browser Engine and GitHub Create/Review reference](../reference/browser-engine-github-create-review.md).

## What this run proved

The captured run established all of the following:

- an isolated Git worktree was created from exact commit `66a655dd17edf280fbf5ebeb43055bef817e49fb`;
- the remote target branch did not exist before the test;
- `repo-harness 0.12.0` initialized the worktree successfully;
- `repo-harness run check-task-workflow --strict` returned `[workflow] OK`;
- Oracle `0.16.1` was installed and the Oracle provider doctor returned `status: ready`;
- Gitleaks `8.30.1` was supplied from the Nix store;
- the `browser-create --dry-run` secret scan passed;
- the dry run created no remote branch;
- the signed-in Chrome profile was bound without explicitly passing `--browser-channel chrome`.

The same run also exposed two blockers that must be resolved before the real Create operation:

1. Oracle reported `browserAppPreselect: false` and did not expose `--browser-app`.
2. The dry-run command omitted `--draft-pr`, so repo-harness generated `draftPr: false` and instructed the browser session not to open a pull request.

## Smoke-test contract

- use a separate worktree at the exact approved base;
- use a new `agent/*` branch and confirm it is absent remotely;
- after a partial browser failure, inspect GitHub state before retrying;
- stop before merge, readiness, comments, reviews, CI reruns, auto-merge, or
  remote deletion.

## 1. Re-enter the isolated workspace

```bash
export STAMP="20260803T114441Z"
export BASE="66a655dd17edf280fbf5ebeb43055bef817e49fb"
export WORKTREE="$HOME/nix-config-browser-create-$STAMP"
export LOCAL_BRANCH="test/browser-create-workspace-$STAMP"
export REMOTE_BRANCH="agent/browser-create-smoke-$STAMP"

cd "$WORKTREE"

pwd
git status --short --branch
git rev-parse HEAD
```

Expected base:

```text
66a655dd17edf280fbf5ebeb43055bef817e49fb
```

Confirm the test branch still does not exist remotely:

```bash
if git ls-remote --exit-code --heads origin "$REMOTE_BRANCH" >/dev/null 2>&1; then
  echo "STOP: remote test branch already exists"
  exit 1
else
  echo "OK: remote test branch does not exist"
fi
```

## 2. Initialize and verify repo-harness

```bash
repo-harness --version
repo-harness init --dry-run
repo-harness init
repo-harness run check-task-workflow --strict
```

The observed successful results were:

```text
repo-harness 0.12.0
[workflow] OK
```

Initialization creates untracked harness files in the isolated worktree. That is expected for this test. Do not add them to the target GitHub branch.

## 3. Provide Gitleaks explicitly

A plain `command -v gitleaks` check failed on the test host. Build Gitleaks from Nix instead:

```bash
GITLEAKS_STORE="$(
  nix build \
    --no-link \
    --print-out-paths \
    nixpkgs#gitleaks
)"

export GITLEAKS="$GITLEAKS_STORE/bin/gitleaks"

printf 'Gitleaks: %s\n' "$GITLEAKS"
"$GITLEAKS" version
```

Observed version:

```text
8.30.1
```

Stop if the version command fails.

## 4. Bind the signed-in Chrome profile

```bash
export CHROME_PROFILE="$HOME/Library/Application Support/Google/Chrome/Default"

repo-harness chatgpt browser-setup \
  --repo . \
  --profile-dir "$CHROME_PROFILE"
```

Do not add `--browser-channel chrome`; `chrome` is already the command default.

A backslash used for shell continuation must be the final character on the line. This is wrong:

```bash
repo-harness chatgpt browser-setup \ --repo . \ --profile-dir "$CHROME_PROFILE"
```

In zsh that form escapes spaces and passes malformed arguments. Put each continuation backslash immediately before a newline, as in the working command above.

The default Chrome profile may produce:

```text
blocked_default_profile
```

That warning is for the deprecated native CDP provider. It does not invalidate an Oracle provider result whose top-level status is `ready`.

## 5. Check Oracle readiness

```bash
repo-harness chatgpt browser-doctor \
  --repo . \
  --provider oracle \
  --json
```

General Oracle readiness requires:

```json
{
  "status": "ready",
  "provider": "oracle"
}
```

For `browser-create`, add the stricter app-preselection gate:

```bash
repo-harness chatgpt browser-doctor \
  --repo . \
  --provider oracle \
  --json |
jq -e '
  .status == "ready"
  and .oracle.optionalCapabilities.browserAppPreselect == true
'
```

Do not start the real Create run when this returns `false`.

The captured host reported:

```json
{
  "status": "ready",
  "oracleVersion": "0.16.1",
  "browserAppPreselect": false,
  "missingCapabilities": []
}
```

This means Oracle is ready for ordinary browser consultations but not for a `browser-create` run that must preselect the GitHub app.

Confirm the missing flag directly:

```bash
oracle --version
oracle --help 2>&1 | grep -F -- '--browser-app'
```

The real Create test remains blocked until the selected Oracle binary exposes `--browser-app` and the doctor reports `browserAppPreselect: true`.

Before changing Oracle, identify how the current binary was installed:

```bash
type -a oracle
ls -l "$(command -v oracle)"
brew list --versions 2>/dev/null | grep -i oracle || true
npm -g ls --depth=0 2>/dev/null | grep -i oracle || true
bun pm ls -g 2>/dev/null | grep -i oracle || true
```

Upgrade or replace Oracle using the same trusted installation source required by the repo-harness Create branch. Re-run the two checks above after the change. Do not silently fall back to the native provider.

## 6. Define the bounded test artifacts

```bash
export APP="GitHub"
export TARGET="tasks/notes/browser-create-smoke-$STAMP.md"
export PLAN="plans/plan-browser-create-smoke-$STAMP.md"
export CONTRACT="tasks/contracts/browser-create-smoke-$STAMP.contract.md"

mkdir -p \
  "$(dirname "$TARGET")" \
  "$(dirname "$PLAN")" \
  "$(dirname "$CONTRACT")"
```

The approved plan and contract must agree on:

- repository `drunkod/nix-config-1`;
- default branch `master`;
- exact base commit `$BASE`;
- target branch `$REMOTE_BRANCH`;
- exactly one allowed target file `$TARGET`;
- exactly one commit with message `test: add browser-create smoke marker`;
- one draft pull request;
- no other GitHub writes.

Inspect them before every run:

```bash
printf '\n--- PLAN ---\n'
cat "$PLAN"

printf '\n--- CONTRACT ---\n'
cat "$CONTRACT"

git status --short
```

## 7. Run the corrected dry run

Include `--draft-pr` in the dry run so the preview matches the intended real operation:

```bash
export DRY_JSON="/tmp/browser-create-$STAMP-dry.json"

repo-harness chatgpt browser-create \
  --repo . \
  --chatgpt-app "$APP" \
  --repository drunkod/nix-config-1 \
  --default-branch master \
  --base-commit "$BASE" \
  --branch "$REMOTE_BRANCH" \
  --plan "$PLAN" \
  --contract "$CONTRACT" \
  --prompt "Create only $TARGET with the exact content specified in the contract. Create exactly one commit with message 'test: add browser-create smoke marker'. Open one draft pull request. Do not change any other file." \
  --title "browser-create-smoke-$STAMP-dry" \
  --gitleaks-bin "$GITLEAKS" \
  --write-output ".ai/harness/handoff/chatgpt/create-$STAMP-smoke-dry.md" \
  --draft-pr \
  --dry-run |
tee "$DRY_JSON"
```

Validate the result:

```bash
jq . "$DRY_JSON"

jq -e '
  .status == "dry_run"
  and .mode == "create"
  and .create.draftPr == true
  and .dryRun.secretScan.status == "passed"
' "$DRY_JSON"
```

Confirm that the preview still made no GitHub write:

```bash
if git ls-remote --exit-code --heads origin "$REMOTE_BRANCH" >/dev/null 2>&1; then
  echo "FAIL: dry run unexpectedly created the remote branch"
  exit 1
else
  echo "OK: dry run made no remote branch"
fi
```

Inspect the generated Oracle command in the JSON. It must contain both:

```text
--browser-app GitHub
```

and an instruction to open a draft pull request. It must not contain `Do not open a pull request`.

## 8. Real-run gate

Proceed only when every check below passes:

```bash
repo-harness run check-task-workflow --strict

"$GITLEAKS" version

repo-harness chatgpt browser-doctor \
  --repo . \
  --provider oracle \
  --json |
jq -e '
  .status == "ready"
  and .oracle.optionalCapabilities.browserAppPreselect == true
'

jq -e '
  .status == "dry_run"
  and .create.draftPr == true
  and .dryRun.secretScan.status == "passed"
' "$DRY_JSON"

! git ls-remote --exit-code --heads origin "$REMOTE_BRANCH" >/dev/null 2>&1
```

Any non-zero result is a stop condition.

## 9. Run the real Create operation

Only after the real-run gate succeeds:

```bash
export CREATE_JSON="/tmp/browser-create-$STAMP.json"

repo-harness chatgpt browser-create \
  --repo . \
  --chatgpt-app "$APP" \
  --repository drunkod/nix-config-1 \
  --default-branch master \
  --base-commit "$BASE" \
  --branch "$REMOTE_BRANCH" \
  --plan "$PLAN" \
  --contract "$CONTRACT" \
  --prompt "Create only $TARGET with the exact content specified in the contract. Create exactly one commit with message 'test: add browser-create smoke marker'. Open one draft pull request. Do not change any other file." \
  --title "browser-create-smoke-$STAMP" \
  --gitleaks-bin "$GITLEAKS" \
  --write-output ".ai/harness/handoff/chatgpt/create-$STAMP-smoke.md" \
  --draft-pr |
tee "$CREATE_JSON"
```

Do not run the command a second time merely because terminal capture is incomplete. First inspect the JSON, the saved session, the remote branch, and GitHub pull requests.

## 10. Independent read-back and Git verification

First inspect the installed read-back syntax:

```bash
repo-harness chatgpt browser-create-readback --help
```

Use only options shown by that help output. Extract the session ID from the Create result:

```bash
export CREATE_SESSION="$(
  jq -r '.sessionId // .session.id // empty' "$CREATE_JSON"
)"

printf 'Create session: %s\n' "$CREATE_SESSION"
```

After read-back completes, verify the remote branch independently:

```bash
git fetch origin "$REMOTE_BRANCH"

git diff --name-only "$BASE" "origin/$REMOTE_BRANCH"
git show "origin/$REMOTE_BRANCH:$TARGET"
git diff --check "$BASE" "origin/$REMOTE_BRANCH"
git rev-list --count "$BASE..origin/$REMOTE_BRANCH"
```

Expected results:

- the changed-file list contains only `$TARGET`;
- the file content exactly matches the contract;
- `git diff --check` prints nothing;
- the branch is exactly one commit ahead;
- the pull request exists and remains draft;
- nothing is merged.

## Failure handling

### `PROMPT_SECRET_SCAN_UNAVAILABLE`

Supply a trusted Gitleaks binary with `--gitleaks-bin`. The Nix-store method in section 3 produced Gitleaks `8.30.1` successfully.

### `browserAppPreselect: false`

Stop before the real run. Oracle may be ready for `browser-consult` while still lacking the app-selection capability required by `browser-create`.

### Dry run reports `draftPr: false`

Add `--draft-pr` to both the dry-run and real commands, then repeat only the dry run. Verify that the generated prompt no longer says `Do not open a pull request`.

### `blocked_default_profile`

When the top-level Oracle status is `ready`, this is a deprecated native-provider warning. Continue using Oracle, but still enforce the separate app-preselection gate.

### Browser capture or parser failure

Do not immediately rerun. Check whether the remote branch, commit, or draft pull request already exists. A browser session may have completed GitHub writes even when local capture was incomplete.

### Remote branch already exists

Stop. Inspect its base, changed files, commits, and pull requests. Never force-update the smoke-test branch.

## Completion checklist

```text
[ ] isolated worktree is on the exact approved base
[ ] remote target branch is absent
[ ] repo-harness strict workflow check passes
[ ] Gitleaks is available and version is at least 8.19
[ ] Chrome profile is bound without an explicit browser-channel flag
[ ] Oracle doctor reports ready
[ ] Oracle doctor reports browserAppPreselect true
[ ] Oracle help exposes --browser-app
[ ] corrected dry run reports draftPr true
[ ] dry-run secret scan passes
[ ] dry run creates no remote branch
[ ] real run is executed once
[ ] independent read-back matches
[ ] exactly one file changed
[ ] exactly one commit created
[ ] pull request remains draft
[ ] nothing is merged
```
