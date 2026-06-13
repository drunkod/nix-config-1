{ lib, inputs, ... }:
{
  flake = { };

  perSystem =
    { pkgs, ... }:
    let
      packageFunctions = lib.filesystem.packagesFromDirectoryRecursive {
        directory = ../../packages;
        callPackage = file: _args: import file;
      };

      builtPackages = lib.fix (
        self:
        lib.mapAttrs (
          _name: packageData:
          let
            packageFn = packageData.default or packageData;
          in
          pkgs.callPackage packageFn (
            self
            // {
              inherit inputs;
            }
          )
        ) packageFunctions
      );
    in
    {
      packages = builtPackages // {
        graphify-skill = inputs.graphify-vhdl-fresh.packages.${pkgs.stdenv.hostPlatform.system}.default;
      };
    };
}
