# Repo Harness Browser Engine, Create, and Review: short tutorial

Browser Engine is separate from Coding MCP. It uses a logged-in ChatGPT Web
session for consultation/planning. The GitHub app Create flow can perform remote
GitHub writes under a bounded contract.

## Browser consultation / planning

### 1. Bind a signed-in Chrome profile

```bash
cd /absolute/path/to/adopted/repository

repo-harness chatgpt browser-setup \
  --repo . \
  --profile-dir "$HOME/Library/Application Support/Google/Chrome/Default"
```

### 2. Verify Oracle

```bash
repo-harness chatgpt browser-doctor \
  --repo . \
  --provider oracle \
  --json
```

Continue only when top-level status is `ready`. Do not silently fall back to the
native provider.

### 3. Dry-run a consultation

```bash
repo-harness chatgpt browser-consult \
  --repo . \
  --provider oracle \
  --dry-run \
  --prompt "Reply exactly OK"
```

Then run without `--dry-run` for a real browser session.

### 4. Plan from allowed files

Browser Engine allows explicit workflow/reference files and denies secrets,
private keys, `.git`, `.ssh`, `_ops`, and local Repo Harness JSON. Attach only
reviewed files:

```bash
repo-harness chatgpt browser-consult \
  --repo . \
  --provider oracle \
  --prompt "Prepare a bounded change brief. Do not implement it." \
  --file README.md \
  --file docs/spec.md \
  --write-output .ai/harness/handoff/chatgpt/brief.md
```

Do not commit browser cookies, tokens, profile state, or session locks.

## GitHub Create and Review

This flow asks the ChatGPT GitHub app to create a dedicated branch, one bounded
commit, and optionally a draft PR. It is not local Coding MCP.

### 1. Prepare approved artifacts

Use committed paths such as:

```text
plans/plan-<task>.md
tasks/contracts/<task>.contract.md
```

The contract must state exact allowed paths, base SHA, target branch, commit
count/message, and draft-PR policy.

### 2. Require Gitleaks

```bash
GITLEAKS="$(nix build --no-link --print-out-paths nixpkgs#gitleaks)/bin/gitleaks"
"$GITLEAKS" version
```

### 3. Dry-run Create

```bash
repo-harness chatgpt browser-create \
  --repo . \
  --chatgpt-app GitHub \
  --repository OWNER/REPOSITORY \
  --default-branch main \
  --base-commit <exact-40-character-sha> \
  --branch agent/<task> \
  --plan plans/plan-<task>.md \
  --contract tasks/contracts/<task>.contract.md \
  --prompt "Implement only the approved contract." \
  --title <task>-dry \
  --gitleaks-bin "$GITLEAKS" \
  --draft-pr \
  --dry-run
```

Confirm the remote branch does not exist before a first real run and still does
not exist after dry-run.

### 4. Real Create

Repeat without `--dry-run` only after reviewing the generated prompt and secret
scan. Do not rerun after partial failure until GitHub state is inspected.

### 5. Independent readback/review

Use a new Browser Engine conversation and:

```bash
repo-harness chatgpt browser-create-verify --help
```

Run the verified command shape for the saved Create result. Review actual GitHub
branch, commit, diff, draft PR, and CI evidence. Merge remains a human decision.

## Safety boundaries

- Browser consultation must not silently become GitHub Create.
- Create, review comments, CI reruns, pushes, PR readiness, and merge are
  separate writes.
- Always use exact repository, base SHA, branch, allowed files, and draft policy.
- Never attach local OAuth/browser/token files.

For full historical details, see
[`repo-harness-chatgpt-browser-setup.md`](repo-harness-chatgpt-browser-setup.md).
