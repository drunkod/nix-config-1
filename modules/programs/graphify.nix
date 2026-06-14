# All Graphify integration in one place.
#
# Source of truth: the external `graphify-vhdl-fresh` flake (offline, code-only,
# no-LLM graphify). This module only re-exposes it into the system config:
#
#   • flake apps    graphify-extract / -update / -query / -mcp / -test / -skill
#   • package       graphify-skill (the Cowork/Desktop Skill zip)
#   • dev shell     `nix develop .#graphify`
#   • home-manager  MCP server (auto-discovers graphify-out/graph.json) + zsh aliases
#
# To activate on a host, add `graphify` to its home-manager imports.
{ inputs, ... }:
{
  # ── flake outputs: apps, skill package, dev shell ───────────────────────────
  perSystem =
    { system, ... }:
    {
      apps = {
        graphify-extract = inputs.graphify-vhdl-fresh.apps.${system}.extract;
        graphify-update = inputs.graphify-vhdl-fresh.apps.${system}.update;
        graphify-query = inputs.graphify-vhdl-fresh.apps.${system}.query;
        graphify-mcp = inputs.graphify-vhdl-fresh.apps.${system}.mcp;
        graphify-test = inputs.graphify-vhdl-fresh.apps.${system}.test;
        graphify-skill = inputs.graphify-vhdl-fresh.apps.${system}.skill;
      };

      packages.graphify-skill = inputs.graphify-vhdl-fresh.packages.${system}.default;

      devShells.graphify = inputs.graphify-vhdl-fresh.devShells.${system}.default;
    };

  # ── home-manager: zsh aliases ───────────────────────────────────────────────
  flake.modules.homeManager.graphify =
    { lib, ... }:
    {
      # Aliases resolve the nix-config flake at runtime via graphify_flake_path.
      programs.zsh = {
        shellAliases = {
          graphify-extract = "nix run \"$(graphify_flake_path)\"#graphify-extract -- .";
          graphify-update = "nix run \"$(graphify_flake_path)\"#graphify-update -- .";
          graphify-query = "nix run \"$(graphify_flake_path)\"#graphify-query --";
          graphify-mcp = "nix run \"$(graphify_flake_path)\"#graphify-mcp --";
          graphify-shell = "nix develop \"$(graphify_flake_path)\"#graphify";
        };

        initContent = lib.mkOrder 600 ''
          graphify_flake_path() {
            local candidate
            for candidate in \
              "$HOME/nix-config" \
              "$HOME/.setup" \
              "$PWD"; do
              if [[ -f "$candidate/flake.nix" ]]; then
                printf '%s\n' "$candidate"
                return 0
              fi
            done

            echo "graphify: could not locate nix-config flake. Expected one of: ~/nix-config, ~/.setup, or current directory." >&2
            return 1
          }
        '';
      };
    };
}
