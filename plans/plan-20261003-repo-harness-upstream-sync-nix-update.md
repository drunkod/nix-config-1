# Plan: Repo Harness upstream synchronization and Nix runtime update

> **Status**: Executing
> **Date**: 2026-10-03
> **Target host**: m1-min
> **Old runtime pin**: 3d0ada93d2d370627b12907a84b2b567ba3c8751
> **Target runtime pin**: ce4a387c0427100d8fd44bfb1d96aa3f638f4956

## Goal

Update the Nix-managed Repo Harness runtime to a published fork revision that contains both the current original/upstream Repo Harness changes and the fork-specific contract-run outer-timeout fix, then regenerate Nix-owned projections and verify the host before resuming application work.

## Required sequencing

1. Synchronize drunkod/repo-harness with the current Ancienttwo/repo-harness main branch in an isolated worktree.
2. Preserve and revalidate the fork-specific dynamic contract-run outer-timeout behavior on top of the synchronized upstream runtime.
3. Publish the synchronized fork commit to GitHub before changing Nix.
4. Pin Nix only to that immutable published fork commit.
5. Do not use nix flake update for this operation; Repo Harness is not a flake input.
6. Build the new Nix generation before activation.
7. Bootstrap the exact pinned runtime, regenerate Codex and Waza projections, run their check modes, and rebuild with the synchronized projections.
8. Prove the original 120-second failure is gone with a contract-run whose declared wall-time exceeds two minutes before resuming the RemoteMCP sprint.

## Completed prerequisite

The fork synchronization and post-sync compatibility repair are published as:
- drunkod/repo-harness@ce4a387c0427100d8fd44bfb1d96aa3f638f4956
- merge commit eb5dbd3d: synchronize current upstream main
- commit 204b3186: carry forward the dynamic outer-timeout implementation
- commit ce4a387c: align package Sprint execution with the upstream 0.20 slim planning runtime

## Expected Nix changes

- modules/programs/repo-harness/runtime-source.json
- modules/programs/repo-harness/codex-projection.json after host projection sync
- modules/programs/repo-harness/waza-source.json after Waza projection sync
- host documentation describing the immutable pin/update sequence

flake.lock is not an expected change.

## Verification

- Repo Harness source: focused timeout/parser tests, TypeScript check, hook bundle build.
- Nix pre-activation: evaluate/build darwinConfigurations.m1-min.system.
- Projection sync: repo-harness-sync-host-config --check and repo-harness-sync-waza --check.
- Nix checks: Repo Harness projection schema + m1-min projection checks.
- Host: repo-harness --version, runtime lock/revision readback, repo-harness-check, protected runtime smoke, plus the upstream repo-harness setup check as a separate advisory readiness audit.
- Regression canary: a >120-second contract-run run must remain alive past the old outer dispatcher ceiling and finish under its declared budget.

## Rollback

Re-activate the previous Nix generation and restore runtime-source.json, Codex projection, and Waza projection to the previous 3d0ada93-bound state. Runtime directories are immutable per revision, so the old runtime remains available until ordinary Nix/user-state cleanup.
