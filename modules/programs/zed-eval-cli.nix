{ inputs, ... }:
{
  flake.modules.homeManager.zed-eval-cli =
    {
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = lib.optionals pkgs.stdenv.isDarwin [
        inputs.self.packages.${pkgs.system}.zed-eval-cli
      ];
    };
}
