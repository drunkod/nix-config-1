# Documentation

Use this page to choose the right authority. Current procedures, implementation
references, historical evidence, and generated workflow files are intentionally
separate.

## Start here

| Goal | Documentation |
|---|---|
| Configure and operate Repo Harness | [Repo Harness](repo-harness/README.md) |
| Solve a common development task with context tools | [Developer recipes](developer-recipes/README.md) |
| Configure CodeGraph or Graphify | [Code-intelligence tools](tools/README.md) |
| Configure a macOS-specific integration | [macOS integrations](macos/README.md) |

## Document types

- **Canonical guide:** current end-to-end procedure and sequencing.
- **Quick tutorial:** abbreviated happy path; follow its canonical guide when a
  setup differs.
- **Reference:** implementation details, internals, or uncommon variants.
- **History:** evidence from a specific test run; not the current procedure.
- **Recipe:** task-oriented workflow after setup.
- **Example snapshot:** complete files for comparison, with higher drift risk.

## Repository workflow scaffold

[`spec.md`](spec.md) is the Repo Harness-required product-specification path. It
is currently a draft scaffold and must remain at this exact location.

## Examples

- [`examples/t3chat-macos-launch-m1-min/`](examples/t3chat-macos-launch-m1-min/README.md)
  is a reference snapshot accompanying the current
  [t3.chat integration guide](macos/t3chat-launch.md).

## Root documentation

The root files remain stable entry points for major repository concerns:

- [`../README.md`](../README.md) — repository overview;
- [`../SETUP-M1.md`](../SETUP-M1.md) — M1 host setup;
- [`../SECURITY.md`](../SECURITY.md) — repository security;
- [`../SOPS.md`](../SOPS.md) — secret management;
- [`../REPO-HARNESS.md`](../REPO-HARNESS.md) — Repo Harness host bootstrap;
- [`../GRAPHIFY-TUTORIAL.md`](../GRAPHIFY-TUTORIAL.md) — Graphify entry point.
