# Repo-harness ChatGPT Browser setup

This guide continues after the `m1-min` repo-harness bootstrap and repository adoption described in [`../REPO-HARNESS.md`](../REPO-HARNESS.md).

It configures the smallest useful workflow:

```text
ChatGPT Browser Plan
        ↓
approved repository plan and task contract
        ↓
ChatGPT GitHub app Create
        ↓
branch, commit, and draft pull request
        ↓
new ChatGPT Browser Review session
        ↓
human decision
```

The Browser Engine is the repo-harness planning and review transport. GitHub-app writes are a separate ChatGPT capability available in the connected environment; they are not an upstream repo-harness file-writing feature.

## 1. Confirm the repository is adopted

Run these commands from the adopted repository or test worktree:

```bash
cd /path/to/repository

repo-harness --version
repo-harness state resolve --json
repo-harness run check-task-workflow --strict
git status --short
```

A newly adopted repository may report:

- `phase: idle`;
- `workflow_profile: lite`;
- no active plan or contract;
- generated repository files and `.gitignore` additions.

That is a valid starting state. The optional global Claude/Codex adapters, CodeGraph integration, external skills, and agent fleet are not required for this browser-only workflow.

Before continuing, inspect every generated file:

```bash
git diff --stat
git diff
find .claude deploy docs/architecture docs/reference-configs docs/researches \
  -type f -maxdepth 4 -print 2>/dev/null
```

Do not commit generated content blindly. Keep the adoption experiment on a separate branch or worktree until the generated repository contract is understood.

## 2. Check Browser Engine readiness

The supported provider is Oracle. Run:

```bash
repo-harness chatgpt browser-doctor \
  --repo . \
  --provider oracle \
  --json
```

Continue only when the result reports:

```json
{
  "status": "ready"
}
```

When the doctor reports a missing or incompatible Oracle or Node runtime, follow the returned `agent_actions`. Do not silently fall back to the deprecated native browser provider.

## 3. Identify the signed-in Chrome profile

Close Chrome before copying or inspecting profile data.

Typical macOS profile locations are:

```text
~/Library/Application Support/Google/Chrome/Default
~/Library/Application Support/Google/Chrome/Profile 1
~/Library/Application Support/Google/Chrome/Profile 2
```

List available profiles:

```bash
find "$HOME/Library/Application Support/Google/Chrome" \
  -maxdepth 1 \
  -type d \
  \( -name 'Default' -o -name 'Profile *' \) \
  -print
```

Choose the profile that is already signed in to ChatGPT:

```bash
export CHROME_PROFILE="$HOME/Library/Application Support/Google/Chrome/Profile 1"
```

Do not commit the profile path, browser cookies, tokens, or copied browser data.

## 4. Bind the Browser Engine to Chrome

Run:

```bash
repo-harness chatgpt browser-setup \
  --repo . \
  --profile-dir "$CHROME_PROFILE" \
  --browser-channel chrome
```

Validate the binding:

```bash
repo-harness chatgpt browser-doctor \
  --repo . \
  --provider oracle \
  --json
```

If the doctor reports `ORACLE_PROFILE_COOKIE_NOT_FOUND`, the selected profile is not the signed-in profile. Select another profile and repeat `browser-setup`.

The repository-local browser binding is private runtime state and should remain ignored by Git.

## 5. Run a harmless planning dry run

Use a documentation-only task for the first test:

```bash
mkdir -p .ai/harness/handoff/gptpro
stamp="$(date -u +%Y%m%dT%H%M%SZ)"

repo-harness chatgpt browser-consult \
  --repo . \
  --provider oracle \
  --dry-run \
  --prompt "
Act as the planner.

Plan a documentation-only change that adds a short Browser Engine
verification section to this repository.

Return:
- goal;
- allowed files;
- forbidden files;
- proposed content;
- acceptance criteria;
- verification steps;
- rollback.

Do not implement the change.
Do not modify GitHub.
Do not claim that commands were run.
" \
  --file AGENTS.md \
  --file REPO-HARNESS.md \
  --file docs/repo-harness-chatgpt-browser-setup.md \
  --write-output \
  ".ai/harness/handoff/gptpro/plan-${stamp}-browser-smoke-test.md"
```

The dry run renders the prompt and attachment bundle without starting the real provider session.

Inspect available sessions:

```bash
repo-harness chatgpt browser-list --repo .
```

Inspect the selected session:

```bash
repo-harness chatgpt browser-session \
  --repo . \
  <session-id>
```

Verify:

- only intended files are attached;
- no secrets or unrelated source trees are included;
- the output path is unique and timestamped;
- the prompt asks for planning rather than implementation.

## 6. Run the real planning session

Repeat the previous `browser-consult` command without:

```text
--dry-run
```

The managed output file and provider terminal state are the result authority. Do not treat incidental terminal output as the plan.

Review the answer manually. Promote only approved conclusions into durable repository artifacts:

```text
plans/plan-browser-smoke-test.md
tasks/contracts/browser-smoke-test.contract.md
```

A minimal task contract should freeze:

```markdown
# Task Contract: browser-smoke-test

## Goal

## Base

- Base branch:
- Base commit:

## Allowed Paths

## Forbidden Paths

## Requirements

## Required Checks

## Acceptance Criteria

## Rollback
```

The raw Browser Engine answer remains evidence; it is not automatically the repository contract.

## 7. Verify the connected GitHub app in ChatGPT

In ChatGPT:

1. Open **Settings**.
2. Open the GitHub app or connected-app settings.
3. Confirm the GitHub account and installation.
4. Select or sync `drunkod/nix-config-1` when repository selection is available.
5. Start a new conversation and select the GitHub app.

Run a read-only smoke test:

```text
Use the GitHub skill and connected GitHub app.

Repository: drunkod/nix-config-1

Fetch repository metadata and read REPO-HARNESS.md from master.
Do not create or update anything.
```

A visible GitHub tool event is required. Assistant prose claiming that a tool was called is not proof of access.

## 8. Run a minimal Create test

After the plan and contract are committed to a branch visible on GitHub, begin a new ChatGPT conversation:

```text
Use the GitHub skill and connected GitHub app.

Repository: drunkod/nix-config-1
Base branch: master

Read:
- AGENTS.md
- plans/plan-browser-smoke-test.md
- tasks/contracts/browser-smoke-test.contract.md
- docs/repo-harness-chatgpt-browser-setup.md

Before writing, return:
1. the exact base commit;
2. the proposed branch name agent/browser-smoke-test;
3. the exact files to change;
4. confirmation that every path is allowed by the contract.

After explicit confirmation:
- create the branch;
- update only the approved documentation file;
- create one commit;
- open a draft pull request;
- do not merge.
```

For several related files, prefer one Git commit rather than one commit per file. Keep the PR in draft state.

## 9. Run an independent Review test

Start another new ChatGPT conversation. Do not reuse the Create conversation.

```text
Use the Review Follow-up and CI Debug skills with the GitHub app.

Repository: drunkod/nix-config-1
Pull request: <number>

Compare the final PR against:
- plans/plan-browser-smoke-test.md
- tasks/contracts/browser-smoke-test.contract.md

Inspect:
- PR metadata;
- exact changed filenames;
- PR patch;
- unresolved review threads;
- GitHub Actions status and logs when available;
- missing verification evidence.

Return:
1. PASS, FAIL, or NEEDS_WORK;
2. blocking findings;
3. non-blocking concerns;
4. requirements proven;
5. requirements not proven;
6. exact next action.

Do not comment on GitHub.
Do not resolve threads.
Do not rerun jobs.
Do not approve or merge the PR.
```

The review result is advisory. A human must inspect the final commit, checks, review threads, and residual risk before merge.

## 10. Save durable review evidence

Promote an approved review summary into:

```text
tasks/reviews/browser-smoke-test.review.md
```

Recommended structure:

```markdown
# Review: browser-smoke-test

## Human Review Card

- Verdict:
- PR:
- Base commit:
- Implementation commit:
- Intended paths:
- Actual paths:
- CI status:
- Failed or skipped checks:
- Residual risk:
- Rollback:
- Recommended action:

## Requirements

## Findings

## Blocking Issues

## Non-Blocking Concerns

## CI Evidence

## Review Threads
```

Creating or updating this file is another GitHub write action and requires explicit approval.

## 11. Keep the trust boundaries

- Browser planning must not modify implementation files.
- GitHub Create must stay inside the approved contract paths.
- Browser Review must use the final PR commit and current CI evidence.
- Browser sessions, cookies, tokens, and temporary capture files remain untracked.
- Comments, review submissions, thread resolution, job reruns, PR readiness, and merge are separate write actions.
- Never enable auto-merge for the smoke test.
- Merge remains a human decision.

## 12. Troubleshooting

### Browser doctor is not ready

Run:

```bash
repo-harness chatgpt browser-doctor \
  --repo . \
  --provider oracle \
  --json
```

Follow the returned `agent_actions`. Do not guess an Oracle installation command when the doctor provides source-aware remediation.

### Browser capture is incomplete

When the session reports `ORACLE_CAPTURE_INCOMPLETE`, resume the existing provider session:

```bash
repo-harness chatgpt browser-followup \
  --repo . \
  --session <session-id> \
  --prompt "Continue and return the complete requested result."
```

Do not submit the original prompt a second time automatically.

### GitHub app cannot see the repository

Check the GitHub app installation and selected repositories in ChatGPT settings. Syncing improves retrieval, but repository access still depends on the GitHub app installation permissions.

### A GitHub file update conflicts

The file content SHA is stale. Refetch the file from the target branch, review the newer content, and construct a new update. Do not force the previous replacement.

### Adoption generated many files

That is expected for the first repository adoption. Keep the work on a separate branch, inspect every generated file, and commit adoption separately from functional changes.

## Minimal checklist

```text
[ ] repo-harness CLI works
[ ] repository adoption completed
[ ] strict workflow check passes
[ ] generated adoption files reviewed
[ ] Browser doctor reports ready
[ ] signed-in Chrome profile is bound
[ ] planning dry run inspected
[ ] real planning session captured
[ ] approved plan and contract committed
[ ] GitHub app read test succeeds
[ ] Create uses a dedicated branch and draft PR
[ ] Review uses a new conversation
[ ] no automated merge
```
