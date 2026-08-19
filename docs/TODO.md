# To Do

Repository follow-up work that is intentionally deferred from the current tested Tududi MCP tunnel MVP.

## Tunnel and MCP proxy follow-ups

- [ ] **Pin the tested `mcp-proxy` version.**
  - Stop relying on an unversioned `npx --yes mcp-proxy` invocation.
  - Prefer a declarative Nix package or otherwise pin the exact tested npm version.
  - Re-run the local `/mcp`, `tunnel.gla.ma`, and TryCloudflare smoke tests after pinning.

- [ ] **Serve Streamable HTTP only for the ChatGPT proxy path.**
  - Change the tested wrappers to use `--server stream` together with `--stateless`.
  - Keep `/mcp` as the public endpoint and avoid exposing the unused `/sse` transport.
  - Re-test ChatGPT tool discovery and MCP `initialize` for both public tunnel variants.

- [ ] **Remove the legacy custom anonymous Tududi gateway after deprecation.**
  - Retire `modules/services/tududi-chatgpt-quick.nix` and its `td-chatgpt-quick-*` commands once the `mcp-proxy` path has been used long enough to be the sole MVP path.
  - Remove remaining legacy documentation references at the same time.
  - Keep the current `mcp-proxy` variants as the canonical anonymous developer-test implementation.

- [ ] **Add managed helper commands for the `mcp-proxy` tunnel flows.**
  - Add commands equivalent to `restart`, `stop`, `url`, and `test` for the `mcp-proxy` variants.
  - Track PID ownership before killing processes so stale PID files cannot terminate unrelated processes.
  - Store generated URLs and logs in a dedicated runtime state directory.
  - Make the test command perform a real MCP `initialize` probe through the public endpoint.
  - Preserve the simple foreground commands for manual debugging.

- [ ] **Extract shared ephemeral-tunnel lifecycle logic.**
  - Identify duplicated logic across Tududi Quick Tunnel, Tududi `mcp-proxy`, the legacy ChatGPT gateway, and Repo Harness tunnel helpers.
  - Share common handling for state directories, PID files, URL extraction, publication delay, retries, logs, shutdown, and smoke tests.
  - Keep service-specific authentication and MCP probes outside the generic helper.

- [ ] **Move the stable public path to an MCP-only named Cloudflare Tunnel.**
  - Reuse `modules/services/cloudflared-mcp-tunnel.nix` for the stable hostname path.
  - Point the named tunnel at the local MCP proxy instead of publishing Tududi's complete HTTP origin on port `3002`.
  - Expose only the MCP endpoint and explicitly required health/authentication endpoints.
  - Add proper MCP authentication/access policy before treating this as a production path.

- [ ] **Add a Nix regression check for the `m1-min` module graph.**
  - Add an evaluation/build check that resolves `darwinConfigurations.m1-min.system` or an equivalent low-cost module evaluation.
  - Ensure Home Manager modules placed under the automatic `import-tree` are exposed through the flake module registry correctly.
  - Catch errors such as the previous `attribute 'pkgs' missing` failure before deployment to the Mac.

## Current tested baseline

Do not treat the tasks above as blockers for the current MVP. The existing `m1-min` configuration has already been tested with both public variants:

- `tududi-mcp-proxy-public` -> `https://<generated>.tunnel.gla.ma/mcp`
- `tududi-mcp-proxy-local` + `cloudflared --protocol http2` -> `https://<generated>.trycloudflare.com/mcp`

The Tududi `tt_...` token remains local and is loaded by `tududi-mcp-stdio` from the existing SOPS-managed secret.