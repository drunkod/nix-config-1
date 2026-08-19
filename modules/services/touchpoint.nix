{
  flake.modules.homeManager.touchpoint =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        escapeShellArg
        hasPrefix
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.services.touchpoint;
      python = pkgs.python312;
      virtualenv = pkgs.python312Packages.virtualenv;
      isOutsideNixStore = path: path != "/nix/store" && !hasPrefix "/nix/store/" path;

      install = pkgs.writeShellApplication {
        name = "touchpoint-install";
        runtimeInputs = [
          pkgs.coreutils
          python
          virtualenv
        ];
        text = ''
          set -euo pipefail

          venv=${escapeShellArg cfg.venvDirectory}
          version=${escapeShellArg cfg.version}

          mkdir -p "$(dirname "$venv")"
          chmod 700 "$(dirname "$venv")"

          # Recreate explicitly so the venv always points at the Python version
          # selected by this Nix generation while keeping a stable macOS path.
          rm -rf "$venv"
          ${virtualenv}/bin/virtualenv \
            --python ${python}/bin/python \
            "$venv"

          "$venv/bin/python" -m pip install \
            --disable-pip-version-check \
            "touchpoint-py==$version"

          installed="$("$venv/bin/python" -c 'import importlib.metadata as m; print(m.version("touchpoint-py"))')"
          [ "$installed" = "$version" ] || {
            echo "Touchpoint: expected version $version, installed $installed" >&2
            exit 1
          }

          echo "Touchpoint $installed installed in $venv"
          echo "Next: grant Accessibility permission in macOS, then run tp-diagnostics."
        '';
      };

      mcp = pkgs.writeShellApplication {
        name = "touchpoint-mcp-nix";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          set -euo pipefail

          venv=${escapeShellArg cfg.venvDirectory}
          expected=${escapeShellArg cfg.version}

          [ -x "$venv/bin/touchpoint-mcp" ] || {
            echo "Touchpoint is not installed yet. Run: tp-install" >&2
            exit 1
          }

          installed="$("$venv/bin/python" -c 'import importlib.metadata as m; print(m.version("touchpoint-py"))' 2>/dev/null || true)"
          [ "$installed" = "$expected" ] || {
            echo "Touchpoint version mismatch: expected $expected, found ''${installed:-missing}. Run: tp-install" >&2
            exit 1
          }

          export PYTHONUNBUFFERED=1
          export TOUCHPOINT_MODE=${escapeShellArg cfg.mode}
          export TOUCHPOINT_CDP_DISCOVER=${escapeShellArg (if cfg.cdpDiscover then "true" else "false")}
          export TOUCHPOINT_AX_MESSAGING_TIMEOUT=${escapeShellArg (toString cfg.axMessagingTimeout)}

          exec "$venv/bin/touchpoint-mcp"
        '';
      };

      diagnostics = pkgs.writeShellApplication {
        name = "touchpoint-diagnostics";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          set -euo pipefail

          venv=${escapeShellArg cfg.venvDirectory}
          [ -x "$venv/bin/python" ] || {
            echo "Touchpoint is not installed yet. Run: tp-install" >&2
            exit 1
          }

          export TOUCHPOINT_MODE=${escapeShellArg cfg.mode}
          export TOUCHPOINT_CDP_DISCOVER=${escapeShellArg (if cfg.cdpDiscover then "true" else "false")}
          export TOUCHPOINT_AX_MESSAGING_TIMEOUT=${escapeShellArg (toString cfg.axMessagingTimeout)}

          exec "$venv/bin/python" -c \
            'import json, touchpoint as tp; print(json.dumps(tp.diagnostics(), indent=2, default=str))'
        '';
      };
    in
    {
      options.services.touchpoint = {
        enable = mkEnableOption "Touchpoint desktop accessibility/MCP tooling";

        version = mkOption {
          type = types.str;
          default = "0.3.0";
          description = "Pinned touchpoint-py version installed into the stable user venv.";
        };

        venvDirectory = mkOption {
          type = types.str;
          default = "${config.home.homeDirectory}/.local/share/touchpoint/venv";
          description = ''
            Stable user-owned Python virtualenv path. Keeping this outside the
            Nix store avoids changing the executable path on every Nix rebuild,
            which is useful for macOS Accessibility permission testing.
          '';
        };

        mode = mkOption {
          type = types.enum [
            "vision"
            "no-vision"
          ];
          default = "no-vision";
          description = "Touchpoint MCP mode. no-vision uses structured accessibility snapshots.";
        };

        cdpDiscover = mkOption {
          type = types.bool;
          default = true;
          description = "Allow Touchpoint to auto-discover Chromium/Electron CDP debug ports.";
        };

        axMessagingTimeout = mkOption {
          type = types.number;
          default = 1.0;
          description = "Seconds Touchpoint waits for a macOS AX application reply.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = hasPrefix "/" cfg.venvDirectory && isOutsideNixStore cfg.venvDirectory;
            message = "Touchpoint venvDirectory must be an absolute path outside the Nix store.";
          }
          {
            assertion = cfg.axMessagingTimeout > 0;
            message = "Touchpoint axMessagingTimeout must be greater than zero.";
          }
        ];

        home.packages = [
          python
          install
          mcp
          diagnostics
        ];

        home.activation.touchpointRuntimeDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p ${escapeShellArg (builtins.dirOf cfg.venvDirectory)}
          run chmod 700 ${escapeShellArg (builtins.dirOf cfg.venvDirectory)}
        '';

        home.shellAliases = {
          tp-install = "${install}/bin/touchpoint-install";
          tp-mcp = "${mcp}/bin/touchpoint-mcp-nix";
          tp-diagnostics = "${diagnostics}/bin/touchpoint-diagnostics";
        };
      };
    };
}
