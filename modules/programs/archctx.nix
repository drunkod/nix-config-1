{
  flake.modules.homeManager.archctx =
    { config, pkgs, ... }:
    let
      archctxVersion = "0.4.2";
      archctxPrefix = "${config.xdg.dataHome}/archctx/npm";
      archctxBin = "${archctxPrefix}/bin/archctx";
      runtimeInputs = with pkgs; [
        nodejs_24
        git
      ];

      archctx = pkgs.writeShellApplication {
        name = "archctx";
        inherit runtimeInputs;
        text = ''
          set -euo pipefail

          if [ ! -x "${archctxBin}" ]; then
            printf '%s\n' \
              "archctx CLI is not installed yet." \
              "" \
              "Run: archctx-bootstrap" \
              "Then verify: archctx doctor" >&2
            exit 127
          fi

          exec "${archctxBin}" "$@"
        '';
      };

      archctxBootstrap = pkgs.writeShellApplication {
        name = "archctx-bootstrap";
        inherit runtimeInputs;
        text = ''
          set -euo pipefail

          mkdir -p "${archctxPrefix}"
          echo "Installing archctx@${archctxVersion}..."
          npm install \
            --global \
            --prefix "${archctxPrefix}" \
            --no-audit \
            --no-fund \
            "archctx@${archctxVersion}"

          test -x "${archctxBin}"
          "${archctxBin}" --help >/dev/null
          "${archctxBin}" doctor
        '';
      };

      archctxStatus = pkgs.writeShellApplication {
        name = "archctx-managed-status";
        inherit runtimeInputs;
        text = ''
          set -euo pipefail
          echo "Pinned version: ${archctxVersion}"
          echo "npm prefix: ${archctxPrefix}"
          node --version
          npm --version
          git --version
          if [ -x "${archctxBin}" ]; then
            npm list --global --prefix "${archctxPrefix}" --depth=0 archctx || true
          else
            echo "Installation state: not installed"
            echo "Run: archctx-bootstrap"
          fi
        '';
      };

      archctxRemove = pkgs.writeShellApplication {
        name = "archctx-remove";
        inherit runtimeInputs;
        text = ''
          set -euo pipefail
          npm uninstall --global --prefix "${archctxPrefix}" archctx || true
        '';
      };
    in
    {
      home.packages = [
        pkgs.nodejs_24
        pkgs.git
        archctx
        archctxBootstrap
        archctxStatus
        archctxRemove
      ];

      home.shellAliases = {
        ac-bootstrap = "archctx-bootstrap";
        ac-status = "archctx-managed-status";
      };
    };
}
