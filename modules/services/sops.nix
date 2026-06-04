{
  flake.modules.homeManager.sops =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkIf mkEnableOption;

      cfg = config.services.sops;
    in
    {
      options.services.sops = {
        enable = mkEnableOption "sops secret management";
      };

      config = mkIf cfg.enable {
        home.packages = with pkgs; [
          age
          sops
        ];

        sops = {
          age = {
            keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
          };
        };
      };
    };
}
