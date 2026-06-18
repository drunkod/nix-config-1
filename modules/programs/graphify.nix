{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      graphify = import ../../nix/graphify.nix {
        inherit pkgs;
        graphify-src = inputs.graphify-src;
      };
    in
    {
      apps = {
        graphify = graphify.apps.graphify;
        graphify-extract = graphify.apps.extract;
        graphify-update = graphify.apps.update;
        graphify-query = graphify.apps.query;
        graphify-mcp = graphify.apps.mcp;
        graphify-mcp-run = graphify.apps.mcp-run;
        graphify-test = graphify.apps.test;
        graphify-skill = graphify.apps.skill;
      };

      packages = {
        graphify = graphify.packages.graphify;
        graphify-extract = graphify.packages.graphify-extract;
        graphify-update = graphify.packages.graphify-update;
        graphify-query = graphify.packages.graphify-query;
        graphify-mcp = graphify.packages.graphify-mcp;
        graphify-mcp-run = graphify.packages.graphify-mcp-run;
        graphify-skill = graphify.packages.skill;
      };

      checks.graphify-skill = graphify.checks.skill;

      devShells.graphify = graphify.devShells.default;
    };

  flake.modules.homeManager.graphify =
    { lib, pkgs, ... }:
    {
      home.packages = [
        inputs.self.packages.${pkgs.system}.graphify
        inputs.self.packages.${pkgs.system}.graphify-extract
        inputs.self.packages.${pkgs.system}.graphify-update
        inputs.self.packages.${pkgs.system}.graphify-query
        inputs.self.packages.${pkgs.system}.graphify-mcp
        inputs.self.packages.${pkgs.system}.graphify-mcp-run
        inputs.self.packages.${pkgs.system}.graphify-skill
      ];

      programs.zsh = {
        shellAliases = {
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
