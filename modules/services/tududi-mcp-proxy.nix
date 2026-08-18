{
  flake.modules.homeManager.tududi-mcp-proxy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkEnableOption mkIf mkOption types;
      cfg = config.services.tududi-mcp-proxy;

      proxyLocal = pkgs.writeShellApplication {
        name = "tududi-mcp-proxy-local";
        runtimeInputs = [ pkgs.nodejs ];
        text = ''
          exec npx --yes mcp-proxy \
            --port ${toString cfg.port} \
            --stateless \
            -- \
            tududi-mcp-stdio
        '';
      };

      proxyTunnel = pkgs.writeShellApplication {
        name = "tududi-mcp-proxy-public";
        runtimeInputs = [ pkgs.nodejs ];
        text = ''
          exec npx --yes mcp-proxy \
            --port ${toString cfg.port} \
            --tunnel \
            --stateless \
            -- \
            tududi-mcp-stdio
        '';
      };
    in
    {
      options.services.tududi-mcp-proxy = {
        enable = mkEnableOption "mcp-proxy Tududi examples";

        port = mkOption {
          type = types.port;
          default = 8080;
        };
      };

      config = mkIf cfg.enable {
        home.packages = [
          proxyLocal
          proxyTunnel
        ];
      };
    };
}
