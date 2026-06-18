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
        graphify-test = graphify.apps.test;
        graphify-skill = graphify.apps.skill;
      };

      packages = {
        graphify = graphify.packages.graphify;
        graphify-mcp = graphify.packages.graphify-mcp;
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
        inputs.self.packages.${pkgs.system}.graphify-mcp
      ];

      programs.zsh = {
        shellAliases = {
          graphify-extract = "nix run \"$(graphify_flake_path)\"#graphify-extract -- .";
          graphify-update = "nix run \"$(graphify_flake_path)\"#graphify-update -- .";
          graphify-query = "nix run \"$(graphify_flake_path)\"#graphify-query --";
          graphify-mcp-run = "nix run \"$(graphify_flake_path)\"#graphify-mcp --";
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
