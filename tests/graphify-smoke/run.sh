#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
fixture="$repo_root/tests/graphify-smoke"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cp -R "$fixture/." "$workdir/"
rm -rf "$workdir/graphify-out"

GRAPHIFY_QUERY_LOG_DISABLE=1 \
GRAPHIFY_MAX_WORKERS=1 \
nix run --accept-flake-config "path:$repo_root#graphify" -- \
  extract "$workdir" --force --no-viz

test -s "$workdir/graphify-out/graph.json"

GRAPHIFY_QUERY_LOG_DISABLE=1 \
GRAPHIFY_MAX_WORKERS=1 \
nix run --accept-flake-config "path:$repo_root#graphify" -- \
  cluster-only "$workdir" --no-viz --no-label

test -s "$workdir/graphify-out/graph.json"
test -s "$workdir/graphify-out/GRAPH_REPORT.md"

echo "graphify smoke test passed"
