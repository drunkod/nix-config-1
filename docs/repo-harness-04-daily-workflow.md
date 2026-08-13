# 4. Daily work with Repo Harness Coding MCP

Use this guide after the repository is adopted, committed, and explicitly
registered. It describes the normal work loop, not installation or emergency
recovery.

## Default operating model

```text
human chooses repository + exact base SHA
  -> ChatGPT read-only canary
    -> open_workspace in managed worktree mode
      -> read applicable instructions
        -> inspect and plan
          -> apply a bounded patch
            -> run targeted commands
              -> inspect diff
                -> human decides whether to preserve, push, or discard
```

ChatGPT is operating a local coding connector with the authority of your local
user for shell commands. A repository grant is not a shell sandbox.

## Step 1: verify the service before each session

```bash
repo-harness-mcp-quick-test
repo-harness-mcp-quick-url
```

The `rh-mcp-*` forms are interactive Zsh aliases and may be unavailable in
non-interactive shells.

`repo-harness-mcp-quick-test` must report all five layers green:

```text
config_ready
local_ready
tunnel_ready
oauth_ready
mcp_ready
```

Quick Tunnel URLs are ephemeral. If the URL changed, update the ChatGPT app and
reauthorize before working.

A green doctor proves transport and schema readiness. It does not prove that
ChatGPT invoked a tool. Require a visible `Called tool` event or a captured tool
transcript.

## Step 2: start with read-only canaries

In a new ChatGPT conversation:

```text
Use Repo Harness Coding and call harness_status.
Do not call any other tool.
Do not modify anything and do not run shell commands.
```

Then:

```text
Use Repo Harness Coding and call harness_doctor.
Do not call any other tool.
Do not modify anything and do not run shell commands.
```

If no tool event appears, treat the ChatGPT surface as blocked. Do not restart or
reconfigure a healthy server repeatedly based only on model prose.

## Step 3: select the exact repository

Ask ChatGPT to call `discover_harness_repos`. Select the exact repository and
confirm it has the intended access mode.

`open_workspace` requires an opaque `repo_id`, not a path or repository name. If
discovery omits the ID, resolve only the exact ID locally:

```bash
REPO=/absolute/path/to/repository
REPO_ROOT="$(cd "$REPO" && pwd -P)"

REPO_ID="$({
  jq -r \
    --arg path "$REPO_ROOT" \
    '.repos[] | select(.path == $path and .accessMode == "read_write") | .id' \
    "$HOME/.repo-harness/registered-repos.json" || true
} | tail -n 1)"

case "$REPO_ID" in
  repo_*) printf '%s\n' "$REPO_ID" ;;
  *) echo "STOP: no exact read_write repo_id for $REPO_ROOT" >&2; exit 1 ;;
esac
```

Share only that one `repo_id` when necessary. Never paste or attach the complete
registry.

## Step 4: choose an exact base

Use a commit containing the Repo Harness adoption files:

```bash
cd /absolute/path/to/repository
git status --short --branch
git rev-parse HEAD
```

Prefer a clean, reviewed SHA. Do not use a moving branch name when exact
reproducibility matters.

If the source checkout is dirty, decide deliberately whether those changes
belong in the task. A managed worktree starts from Git history, not from
uncommitted source changes.

## Step 5: open a managed workspace

Recommended tool arguments:

```json
{
  "repo_id": "repo_...",
  "mode": "worktree",
  "base_ref": "<exact-commit-sha>"
}
```

Use `worktree`, not `checkout`, for normal ChatGPT work. Existing-checkout mode
removes the main isolation boundary and should require an explicit reason.

Before allowing edits, inspect the returned:

- `workspace_id`;
- opaque repository identity and managed branch;
- `base_sha`;
- `dirty_source` status;
- applicable `AGENTS.md` / `CLAUDE.md` / repository instructions.

The remote tool intentionally does not reveal the local managed-worktree path.
Do not ask ChatGPT to discover that path through shell commands.

At the pinned upstream revision, `open_workspace` should persist managed
workspaces to the same state read by `repo-harness mcp workspaces list --json`.
A live validation nevertheless returned an empty local list while the MCP
workspace ID remained usable. Treat that as an observed state/installation
discrepancy: preserve the `open_workspace` response as immediate evidence, do
not assume local cleanup will work, and investigate the active CLI/service state
before discarding the workspace.

Stop if the base SHA, repository, or instructions are not what you approved.

## Step 6: make the task bounded

Give ChatGPT a narrow contract:

```text
Goal: <one concrete outcome>
Allowed paths: <explicit files/directories>
Forbidden paths: everything else
Base SHA: <exact SHA>
Validation: <targeted commands>
Stop after: show status and diff; do not commit or push
```

For a small change, use the effective Lite workflow: brief → edit → targeted
check. Do not create heavyweight plans merely for ceremony.

For higher-risk changes, ask Repo Harness to resolve the effective profile:

```bash
repo-harness state resolve \
  --target-path path/to/file \
  --operation modify \
  --json
```

The resolved workflow may raise the task to Standard or Strict.

## Step 7: initialize CodeGraph in a new managed worktree

A source-checkout `.codegraph/` index is not copied into an ignored managed
worktree, and `open_workspace` does not initialize one. Before the first patch,
approve one exact workspace command:

```text
codegraph init .
```

Verify with `codegraph status . --json` when needed. This uses `exec_command`,
which has local-user shell authority, so do not combine it with unrelated setup
or source changes.

If a patch was already applied and only its index refresh failed, do not repeat
the patch. Initialize/sync CodeGraph separately; the mutation already happened.

## Step 8: inspect before editing

Within the managed workspace:

1. read applicable instruction files;
2. read only task-relevant source;
3. inspect current behavior or reproduce the issue;
4. state the intended files and validation;
5. ask for confirmation before crossing a write boundary when required.

CodeGraph and Graphify may help navigate the code, but their output must be
verified against source. A missing/stale index does not authorize guessing.

## Step 9: edit and validate

Use `apply_patch` for bounded file changes. Use `exec_command` only for commands
that are necessary and understood.

Recommended sequence:

```text
read -> apply_patch -> targeted test -> git status -> git diff
```

Shell safety:

- commands run with local-user authority and may leave the repository;
- do not use shell commands to bypass a file-tool denial;
- do not read credentials, browser state, OAuth state, `_ops`, or unrelated
  repositories;
- avoid destructive Git commands;
- do not start indefinite servers or watchers without an explicit need;
- do not install global tools over Nix-managed state.

A mutation may succeed even if CodeGraph refresh fails. Do not repeat the write
just to repair indexing. Refresh the index separately.

## Step 10: run the traversal negative test for a new setup

Before trusting a newly registered repository, ask for one harmless denied read:

```text
Using the current managed workspace, attempt to read ../outside.
Do not use exec_command or another tool to bypass the result.
Report the exact denial and stop.
```

Expected: traversal is rejected. Any successful outside read is a security
failure; stop the session and downgrade repository access.

## Step 11: review the result

Require ChatGPT to show:

```text
workspace_id
base_sha
changed paths
git status --short
git diff --stat
git diff
tests actually run and their results
remaining risks
```

Do not accept “looks good” without the actual diff and validation evidence.

Editing, committing, pushing, opening a PR, and merging are separate approval
boundaries. The default task should stop before commit and push.

## Step 12: preserve or discard deliberately

List managed workspaces locally:

```bash
repo-harness mcp workspaces list --json
```

Repo Harness intentionally has no remote workspace-delete tool. Local cleanup is
conservative:

```bash
repo-harness mcp workspaces cleanup \
  --workspace-id <workspace-id> \
  --json
```

Cleanup refuses dirty or unmerged worktrees. First choose one:

- preserve the branch/commit and integrate it through normal Git review;
- export or copy a reviewed diff;
- explicitly discard the work through a safe local Git operation;
- leave the workspace intact for later inspection.

Never force-clean a workspace merely to make a status command green.

## Daily checklist

```text
[ ] repo-harness-mcp-quick-test is green
[ ] ChatGPT produced visible tool events
[ ] exact repository and repo_id selected
[ ] exact adopted base SHA selected
[ ] managed worktree mode used
[ ] CodeGraph initialized in this managed worktree before its first patch
[ ] applicable instructions read
[ ] allowed and forbidden paths stated
[ ] only bounded changes made
[ ] targeted validation actually ran
[ ] status and diff reviewed
[ ] commit/push/PR/merge handled as separate approvals
[ ] workspace preserved or cleaned deliberately
```

For OAuth, tunnel, authorization, security, and recovery problems, continue with
[`repo-harness-05-operations-security-troubleshooting.md`](repo-harness-05-operations-security-troubleshooting.md).
