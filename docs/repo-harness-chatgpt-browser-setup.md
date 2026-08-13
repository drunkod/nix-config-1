# Repo-harness ChatGPT Browser setup

> Separate optional workflow. This Browser Engine + GitHub app path is not Coding MCP. For local managed-workspace coding, start with [`repo-harness-01-onboard-repository.md`](repo-harness-01-onboard-repository.md) and [`repo-harness-02-daily-workflow.md`](repo-harness-02-daily-workflow.md).

This guide continues after the `m1-min` repo-harness bootstrap and repository adoption described in [`../REPO-HARNESS.md`](../REPO-HARNESS.md).

It configures the smallest useful workflow:

```text
ChatGPT Browser Plan
        ↓
approved bounded change brief
        ↓
ChatGPT GitHub app Create
        ↓
branch, commit, and draft pull request
        ↓
new ChatGPT Review conversation
        ↓
human decision
```

The repo-harness Browser Engine is the planning transport and local audit store. GitHub-app reads and writes are a separate ChatGPT capability available in the connected environment; they are not an upstream repo-harness file-writing feature.

## 1. Confirm the repository is adopted

Run from the adopted repository or test worktree:

```bash
cd /path/to/repository

repo-harness --version
repo-harness state resolve --json
repo-harness run check-task-workflow --strict
git status --short
```

A new adoption may report:

- `phase: idle`;
- `workflow_profile: lite`;
- no active plan or contract;
- generated repository files and `.gitignore` additions.

That is a valid starting state. For a low-risk documentation smoke test, respect the `lite` guidance: use a bounded brief, one approved file, and a targeted check. Do not create a heavyweight plan or task contract merely to satisfy ceremony.

Optional global Claude/Codex adapters, CodeGraph, external skills, and the agent fleet are not required for this browser-only workflow.

Inspect the generated files before committing adoption:

```bash
git diff --stat
git diff
find .claude deploy docs/architecture docs/reference-configs docs/researches \
  -type f -maxdepth 4 -print 2>/dev/null
```

Keep the adoption experiment on a separate branch or worktree until the generated repository contract is understood.

## 2. Check Browser Engine readiness

Oracle is the supported provider:

```bash
repo-harness chatgpt browser-doctor \
  --repo . \
  --provider oracle \
  --json
```

Continue only when the top-level result reports:

```json
{
  "status": "ready",
  "provider": "oracle"
}
```

When `status` is `ready`, an entry such as this under `native.productSession` does not block Oracle:

```text
blocked_default_profile
```

That warning applies to the deprecated native Chrome CDP provider. Chrome 136+ blocks native CDP validation against the current default Chrome data directory. Oracle may still use the selected signed-in profile through its cookie-path support.

When the doctor reports a missing or incompatible Oracle or Node runtime, follow its returned `agent_actions`. Do not silently switch to the native provider.

## 3. Bind the signed-in Chrome profile

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

Choose the profile signed in to ChatGPT:

```bash
export CHROME_PROFILE="$HOME/Library/Application Support/Google/Chrome/Default"
```

Bind it:

```bash
repo-harness chatgpt browser-setup \
  --repo . \
  --profile-dir "$CHROME_PROFILE"
```

Validate again:

```bash
repo-harness chatgpt browser-doctor \
  --repo . \
  --provider oracle \
  --json
```

The binding is local runtime state. Keep these paths ignored:

```text
.repo-harness/chatgpt-browser.local.json
.repo-harness/chatgpt-browser.tokens.json
.ai/harness/chatgpt/browser-lock.json
.ai/harness/chatgpt/sessions/
```

Do not copy or commit browser cookies, profile contents, tokens, or passwords.

## 4. Understand the Browser Engine file policy

The Browser Engine accepts explicit repository files only from its allowed surface.

Allowed by default:

```text
AGENTS.md
CLAUDE.md
README.md
docs/**
plans/**
tasks/**
.ai/context/**
.ai/harness/**
package.json
```

Denied by default include secrets, private keys, `.git/**`, `.ssh/**`, build output, `_ops/**`, and `.repo-harness/**/*.json`.

An arbitrary root-level Markdown file is not automatically allowed. For example:

```text
REPO-HARNESS.md
```

is rejected with:

```text
path is not allowed for read
```

Do not bypass the policy by copying arbitrary files blindly. Prefer an allowed canonical input such as `README.md`, `AGENTS.md`, or a reviewed file under `docs/`.

## 5. Run the transport smoke test

First validate session creation without attachments:

```bash
repo-harness chatgpt browser-consult \
  --repo . \
  --provider oracle \
  --dry-run \
  --prompt "Reply exactly OK"
```

List sessions:

```bash
repo-harness chatgpt browser-list --repo .
```

Inspect the dry-run session:

```bash
repo-harness chatgpt browser-session \
  --repo . \
  <session-id>
```

Confirm that it is marked `dry_run` and that no real browser conversation was opened.

Then run the real transport check:

```bash
repo-harness chatgpt browser-consult \
  --repo . \
  --provider oracle \
  --prompt "Reply exactly OK"
```

Expected result: a completed Oracle session whose managed output contains `OK`.

## 6. Run the first planning dry run

Use only allowed files that already exist in the adopted worktree:

```bash
mkdir -p .ai/harness/handoff/gptpro
stamp="$(date -u +%Y%m%dT%H%M%SZ)"

repo-harness chatgpt browser-consult \
  --repo . \
  --provider oracle \
  --dry-run \
  --prompt "
Act as the planner.

Prepare a bounded documentation change brief for adding a short
Browser Engine verification note to docs/spec.md.

Return:
- goal;
- exact allowed file;
- forbidden files;
- exact proposed content;
- acceptance criteria;
- verification steps;
- rollback.

Use only docs/spec.md as the proposed implementation target.
Do not implement the change.
Do not modify GitHub.
Do not claim that commands were run.
" \
  --file AGENTS.md \
  --file README.md \
  --file docs/spec.md \
  --write-output \
  ".ai/harness/handoff/gptpro/brief-${stamp}-browser-smoke-test.md"
```

The dry run validates:

- the prompt;
- the file policy;
- attachment sizes;
- the unique output path;
- local session creation.

Inspect the saved session:

```bash
repo-harness chatgpt browser-list --repo .
repo-harness chatgpt browser-session --repo . <session-id>
```

Verify that only these inputs are present:

```text
AGENTS.md
README.md
docs/spec.md
```

## 7. Run the real planning session

Repeat the preceding command without:

```text
--dry-run
```

The managed output file and provider terminal state are the result authority. Incidental terminal output is not the approved brief.

Review the brief manually. For the first `lite` smoke test, keep it as evidence under:

```text
.ai/harness/handoff/gptpro/
```

Do not promote it into a heavyweight plan or task contract unless the effective-state resolver selects a workflow that requires those artifacts.

## 8. Verify the GitHub app in ChatGPT

In ChatGPT:

1. Open **Settings**.
2. Open the GitHub app or connected-app settings.
3. Confirm the GitHub account and installation.
4. Select or sync `drunkod/nix-config-1` when repository selection is available.
5. Start a new conversation and select the GitHub app.

Run a read-only test:

```text
Use the GitHub skill and connected GitHub app.

Repository: drunkod/nix-config-1

Fetch repository metadata and read README.md from master.
Do not create or update anything.
```

A visible GitHub tool event is required. Assistant prose claiming that a tool was called is not evidence of access.

## 9. Run a minimal Create smoke test

The Oracle brief exists only in the local test worktree. Before GitHub Create, either:

- copy the approved brief text into the ChatGPT request; or
- commit an approved brief to a branch visible on GitHub.

For the smallest test, paste the reviewed brief and use this prompt in a new GitHub-app conversation:

```text
Use the GitHub skill and connected GitHub app.

Repository: drunkod/nix-config-1
Base branch: master

Implement this approved documentation brief:
<paste the reviewed brief>

Before writing:
1. report the exact base commit;
2. propose branch agent/browser-smoke-test;
3. confirm that only docs/spec.md will change;
4. show the proposed text.

After explicit confirmation:
- create the branch;
- update only docs/spec.md;
- create one commit;
- open a draft pull request;
- do not mark it ready;
- do not merge.
```

GitHub writes are explicit actions. Confirm the repository, branch, target path, and proposed content before authorizing them.

## 10. Run an independent Review smoke test

Start a separate ChatGPT conversation. Do not reuse the Create conversation.

```text
Use the Review Follow-up and CI Debug skills with the GitHub app.

Repository: drunkod/nix-config-1
Pull request: <number>

Review the final PR against this approved brief:
<paste the approved brief>

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

The review result is advisory. A human must inspect the final commit, checks, open threads, and residual risk before merge.

## 11. Troubleshooting

### `path is not allowed for read`

Check the default allowlist in section 4. Replace an arbitrary root file with an allowed canonical path such as:

```text
README.md
AGENTS.md
docs/spec.md
```

Do not move secret or unrelated content into an allowed directory merely to bypass the path gate.

### `blocked_default_profile`

When the top-level provider is Oracle and `status` is `ready`, this is a native-provider diagnostic warning only. Continue with Oracle.

For native CDP diagnostics, use a separate non-default automation user-data directory. The native provider is deprecated and is not needed for this workflow.

### Browser capture is incomplete

When a session reports `ORACLE_CAPTURE_INCOMPLETE`, resume the saved provider session:

```bash
repo-harness chatgpt browser-followup \
  --repo . \
  --session <session-id> \
  --prompt "Continue and return the complete requested result."
```

Do not automatically resubmit the original prompt because Oracle may already have submitted it.

### GitHub app cannot see the repository

Check the app installation, selected account or organisation, and repository permissions in ChatGPT settings. A visible tool event is required.

### A GitHub file update conflicts

The content SHA is stale. Refetch the file from the target branch, review the newer content, and construct a new update. Do not force the old replacement.

## Minimal checklist

```text
[ ] repo-harness CLI works
[ ] repository adoption completed
[ ] strict workflow check passes
[ ] generated adoption files reviewed
[ ] Oracle doctor reports ready
[ ] signed-in Chrome profile is bound
[ ] no-attachment dry run succeeds
[ ] real Reply-exactly-OK consult succeeds
[ ] planning dry run uses only allowed paths
[ ] real bounded brief is captured
[ ] GitHub app read test succeeds
[ ] Create uses a dedicated branch and draft PR
[ ] Review uses a new conversation
[ ] no automated merge
```
