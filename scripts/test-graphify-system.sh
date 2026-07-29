#!/usr/bin/env bash
set -Eeuo pipefail

NIX_CONFIG_ROOT="${NIX_CONFIG_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
TEST_ROOT="${GRAPHIFY_TEST_ROOT:-$HOME/Documents/work/graphify-command-test}"
REPO_A="$TEST_ROOT/repo-a"
REPO_B="$TEST_ROOT/repo-b"
NON_GIT="$TEST_ROOT/non-git"
LOG_DIR="$TEST_ROOT/logs"
RUNTIME_DIR="${GRAPHIFY_NIX_STATE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/graphify-nix}"
RUNTIME_PYTHON="$RUNTIME_DIR/.venv/bin/python"
EXPECTED_MCP_VERSION="1.26.0"

unset GRAPHIFY_GRAPH_PATH GRAPHIFY_PROJECT_ROOT GRAPHIFY_MCP_STATE_FILE

section() {
  printf '\n\n============================================================\n'
  printf '%s\n' "$1"
  printf '============================================================\n'
}

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

case "$TEST_ROOT" in
  "$HOME/Documents/work/graphify-command-test"|/tmp/graphify-command-test)
    ;;
  *)
    fail "Refusing to remove unexpected test directory: $TEST_ROOT"
    ;;
esac

section "1. Verify activated commands"

commands=(
  graphify
  graphify-extract
  graphify-update
  graphify-query
  graphify-mcp
  graphify-mcp-find-graph
  graphify-mcp-set-graph
  graphify-mcp-run
  graphify-mcp-auto
  graphify-mcp-saved
  graphify-skill
)

for command_name in "${commands[@]}"; do
  command_path="$(command -v "$command_name" || true)"
  [ -n "$command_path" ] || fail "$command_name is missing; rebuild m1-min and open a new terminal"
  printf '%-30s %s\n' "$command_name" "$command_path"
done

pass "All installed Graphify commands are on PATH"

section "2. Run the platform-specific Nix check"

cd "$NIX_CONFIG_ROOT"
nix build .#checks.aarch64-darwin.graphify-skill -L

pass "Graphify Nix check passed"

section "3. Create isolated Git repositories"

rm -rf "$TEST_ROOT"
mkdir -p \
  "$REPO_A/src" \
  "$REPO_B/src" \
  "$NON_GIT/src" \
  "$TEST_ROOT/graphify-out" \
  "$LOG_DIR"

touch "$TEST_ROOT/graphify-out/graph.json"

git -C "$REPO_A" init --quiet
git -C "$REPO_B" init --quiet

for repository in "$REPO_A" "$REPO_B" "$NON_GIT"; do
  cat > "$repository/.graphifyignore" <<'EOF'
*.md
*.txt
*.pdf
*.png
*.jpg
*.jpeg
*.svg
*.yaml
*.yml

graphify-out/
.venv/
node_modules/
dist/
build/
EOF
done

cat > "$REPO_A/src/service.py" <<'PY'
class AlphaRepository:
    def find_name(self, user_id: str) -> str:
        return f"alpha-{user_id}"


class AlphaService:
    def __init__(self, repository: AlphaRepository) -> None:
        self.repository = repository

    def display_name(self, user_id: str) -> str:
        return self.repository.find_name(user_id)
PY

cat > "$REPO_A/src/main.py" <<'PY'
from service import AlphaRepository, AlphaService


def main() -> None:
    service = AlphaService(AlphaRepository())
    print(service.display_name("42"))


if __name__ == "__main__":
    main()
PY

cat > "$REPO_B/src/gateway.py" <<'PY'
class BetaGateway:
    def fetch_status(self) -> str:
        return "ready"


class BetaController:
    def __init__(self, gateway: BetaGateway) -> None:
        self.gateway = gateway

    def status(self) -> str:
        return self.gateway.fetch_status()
PY

cat > "$REPO_B/src/main.py" <<'PY'
from gateway import BetaController, BetaGateway


def main() -> None:
    controller = BetaController(BetaGateway())
    print(controller.status())


if __name__ == "__main__":
    main()
PY

cat > "$NON_GIT/src/plain.py" <<'PY'
def plain_project() -> str:
    return "explicit-root-only"
PY

pass "Created repository A, repository B, an ancestor graph, and a non-Git project"

section "4. Test graphify and graphify-extract"

export GRAPHIFY_QUERY_LOG_DISABLE=1
export GRAPHIFY_MAX_WORKERS=1

graphify --help >"$LOG_DIR/graphify-help.log" 2>&1

graphify-extract "$REPO_A" --force --no-viz 2>&1 | tee "$LOG_DIR/extract-a.log"
graphify-extract "$REPO_B" --force --no-viz 2>&1 | tee "$LOG_DIR/extract-b.log"
graphify-extract "$NON_GIT" --force --no-viz 2>&1 | tee "$LOG_DIR/extract-non-git.log"

test -s "$REPO_A/graphify-out/graph.json"
test -s "$REPO_A/graphify-out/manifest.json"
test -s "$REPO_B/graphify-out/graph.json"
test -s "$REPO_B/graphify-out/manifest.json"
test -s "$NON_GIT/graphify-out/graph.json"
grep -q 'AlphaService' "$REPO_A/graphify-out/graph.json"
grep -q 'BetaController' "$REPO_B/graphify-out/graph.json"

pass "All test projects produced valid independent graphs"

section "5. Test graphify-query"

graphify-query \
  "AlphaService AlphaRepository" \
  --graph "$REPO_A/graphify-out/graph.json" \
  2>&1 | tee "$LOG_DIR/query-a.log"

grep -qi 'Alpha' "$LOG_DIR/query-a.log" || fail "query completed without an Alpha result"

pass "graphify-query completed"

section "6. Test graphify-update"

cat >> "$REPO_A/src/service.py" <<'PY'


class AlphaFormatter:
    def format_name(self, value: str) -> str:
        return value.upper()
PY

graphify-update "$REPO_A" 2>&1 | tee "$LOG_DIR/update-a.log"

test -s "$REPO_A/graphify-out/graph.json"
test -s "$REPO_A/graphify-out/manifest.json"
grep -q 'AlphaFormatter' "$REPO_A/graphify-out/graph.json"

pass "Incremental update preserved and refreshed the graph"

section "7. Test explicit saved state"

graphify-mcp-set-graph --clear
saved_graph="$(graphify-mcp-set-graph "$REPO_A")"
shown_graph="$(graphify-mcp-set-graph --show)"

test "$saved_graph" = "$REPO_A/graphify-out/graph.json"
test "$shown_graph" = "$saved_graph"

pass "Repository A was deliberately saved for explicit saved mode"

section "8. Test Git-bound repository isolation"

workspace_graph="$(cd "$REPO_B/src" && graphify-mcp-find-graph)"
test "$workspace_graph" = "$REPO_B/graphify-out/graph.json"
test "$workspace_graph" != "$saved_graph"

pass "Repository B selects its own Git-root graph"

mv "$REPO_B/graphify-out/graph.json" "$REPO_B/graphify-out/graph.json.hidden"

set +e
(
  cd "$REPO_B/src"
  graphify-mcp-find-graph
) >"$LOG_DIR/fail-closed.out" 2>"$LOG_DIR/fail-closed.err"
find_status=$?
set -e

mv "$REPO_B/graphify-out/graph.json.hidden" "$REPO_B/graphify-out/graph.json"

if [ "$find_status" -eq 0 ]; then
  cat "$LOG_DIR/fail-closed.err" >&2
  cat "$LOG_DIR/fail-closed.out" >&2
  fail "automatic discovery escaped repository B's Git root"
fi

grep -F "Git repository root has no graphify-out/graph.json: $REPO_B" \
  "$LOG_DIR/fail-closed.err" >/dev/null \
  || fail "fail-closed error did not identify repository B"

pass "Automatic discovery cannot select the ancestor or saved graph"

section "9. Test non-Git and explicit environment selection"

set +e
(
  cd "$NON_GIT/src"
  graphify-mcp-find-graph
) >"$LOG_DIR/non-git.out" 2>"$LOG_DIR/non-git.err"
non_git_status=$?
set -e

[ "$non_git_status" -ne 0 ] || fail "automatic discovery unexpectedly accepted a non-Git folder"

grep -F 'current directory is not inside a Git repository' "$LOG_DIR/non-git.err" >/dev/null

explicit_non_git="$(
  cd "$NON_GIT/src"
  GRAPHIFY_PROJECT_ROOT="$NON_GIT" graphify-mcp-find-graph
)"
test "$explicit_non_git" = "$NON_GIT/graphify-out/graph.json"

environment_graph="$(
  cd "$REPO_B/src"
  GRAPHIFY_GRAPH_PATH="$REPO_A/graphify-out/graph.json" graphify-mcp-find-graph
)"
test "$environment_graph" = "$REPO_A/graphify-out/graph.json"

set +e
GRAPHIFY_GRAPH_PATH="$TEST_ROOT/missing-graph.json" \
  graphify-mcp-find-graph \
  >"$LOG_DIR/invalid-env.out" \
  2>"$LOG_DIR/invalid-env.err"
invalid_status=$?
set -e

[ "$invalid_status" -ne 0 ] || fail "invalid GRAPHIFY_GRAPH_PATH did not fail closed"

pass "Non-Git folders require an explicit root and invalid paths fail closed"

section "10. Verify MCP Python SDK compatibility"

[ -x "$RUNTIME_PYTHON" ] || fail "Graphify runtime Python is missing: $RUNTIME_PYTHON"

mcp_version="$("$RUNTIME_PYTHON" -c 'from importlib.metadata import version; print(version("mcp"))')"
test "$mcp_version" = "$EXPECTED_MCP_VERSION" \
  || fail "expected mcp==$EXPECTED_MCP_VERSION, found mcp==$mcp_version"

"$RUNTIME_PYTHON" - <<'PY'
from mcp.types import AnyUrl
PY

pass "MCP SDK version and AnyUrl API are compatible"

section "11. Test MCP server startup"

mcp_smoke() {
  local label="$1"
  local expected_graph="$2"
  shift 2

  local stdout_log="$LOG_DIR/mcp-${label}.out"
  local stderr_log="$LOG_DIR/mcp-${label}.err"
  local pid=""

  set +e
  "$@" </dev/null >"$stdout_log" 2>"$stderr_log" &
  pid=$!

  for _ in {1..30}; do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
  fi

  wait "$pid" 2>/dev/null
  set -e

  cat "$stderr_log"

  grep -F "$expected_graph" "$stderr_log" >/dev/null \
    || fail "$label MCP did not report the expected graph"

  if grep -E 'Traceback|ImportError|ModuleNotFoundError|graphify-mcp is not installed' "$stderr_log" >/dev/null; then
    fail "$label MCP produced a Python/runtime error"
  fi
}

mcp_smoke explicit "$REPO_A/graphify-out/graph.json" graphify-mcp-run "$REPO_A"
mcp_smoke automatic "$REPO_B/graphify-out/graph.json" bash -lc "cd '$REPO_B/src' && exec graphify-mcp-auto"
mcp_smoke saved "$REPO_A/graphify-out/graph.json" graphify-mcp-saved

pass "Explicit, automatic, and saved MCP modes start with correct graphs"

section "12. Test Graphify skill command"

graphify-skill --help >"$LOG_DIR/graphify-skill-help.log" 2>&1

pass "graphify-skill command completed"

section "13. Clean saved global state"

graphify-mcp-set-graph --clear

set +e
graphify-mcp-set-graph --show \
  >"$LOG_DIR/show-after-clear.out" \
  2>"$LOG_DIR/show-after-clear.err"
clear_status=$?
set -e

[ "$clear_status" -ne 0 ] || fail "saved graph still exists after --clear"

pass "Saved state was cleared"

printf '\n\nALL GRAPHIFY TESTS PASSED\n'
printf 'Test repositories: %s\n' "$TEST_ROOT"
printf 'Logs: %s\n' "$LOG_DIR"
