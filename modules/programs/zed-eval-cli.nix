{
  flake.modules.homeManager.zed-eval-cli =
    {
      lib,
      pkgs,
      ...
    }:
    let
      zedEvalPinnedCommit = "24e25552b1259d56a6fdd7956a419ed9e8a1a25e";
      zedEvalRustToolchain = "1.97.1";

      zedEvalBootstrap = pkgs.writeShellApplication {
        name = "repo-harness-zed-eval-bootstrap";
        runtimeInputs = with pkgs; [
          cmake
          coreutils
          git
          rustup
        ];
        text = ''
          set -euo pipefail

          pin="${zedEvalPinnedCommit}"
          toolchain="${zedEvalRustToolchain}"
          data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
          root="$data_home/repo-harness/zed-eval/$pin"
          source_dir="$root/zed"
          bin_dir="$root/bin"
          eval_cli="$bin_dir/eval-cli"
          force=0

          if [ "''${1:-}" = "--force" ]; then
            force=1
            shift
          fi
          if [ "$#" -ne 0 ]; then
            echo "usage: repo-harness-zed-eval-bootstrap [--force]" >&2
            exit 2
          fi

          if [ "$(uname -s)" != "Darwin" ]; then
            echo "repo-harness Zed eval bootstrap is currently configured for macOS only." >&2
            exit 2
          fi

          if [ -x "$eval_cli" ] && [ "$force" -eq 0 ]; then
            echo "eval-cli is already installed for the audited Zed pin:"
            echo "  $eval_cli"
            echo
            echo "Run rh-zed-eval-bootstrap --force to rebuild it."
            exit 0
          fi

          # Zed's Metal build cannot use the standalone Command Line Tools SDK.
          # When full Xcode is installed, prefer it for this bootstrap without
          # mutating the machine-wide xcode-select setting or requiring sudo.
          default_xcode="/Applications/Xcode.app/Contents/Developer"
          active_developer_dir="$(/usr/bin/xcode-select -p 2>/dev/null || true)"

          if [ -z "''${DEVELOPER_DIR:-}" ] \
            && [ -d "$default_xcode" ] \
            && { [ -z "$active_developer_dir" ] \
              || [ "$active_developer_dir" = "/Library/Developer/CommandLineTools" ]; }
          then
            export DEVELOPER_DIR="$default_xcode"
            echo "Using full Xcode for the Zed eval-cli build:"
            echo "  $DEVELOPER_DIR"
            if [ -n "$active_developer_dir" ]; then
              echo "Global xcode-select remains unchanged:"
              echo "  $active_developer_dir"
            fi
            echo
          fi

          developer_dir="''${DEVELOPER_DIR:-$active_developer_dir}"

          if [ -z "$developer_dir" ]; then
            printf '%s\n' \
              "Xcode is required to build Zed eval-cli on macOS." \
              "Install full Xcode, open it once, then rerun rh-zed-eval-bootstrap." >&2
            exit 2
          fi

          if [ "$developer_dir" = "/Library/Developer/CommandLineTools" ]; then
            printf '%s\n' \
              "Only Apple's standalone Command Line Tools are active:" \
              "  $developer_dir" \
              "" \
              "Zed's macOS build requires full Xcode because eval-cli links dependencies that compile Metal shaders." \
              "Install/open Xcode.app, then rerun rh-zed-eval-bootstrap." \
              "The bootstrap will use /Applications/Xcode.app/Contents/Developer automatically;" \
              "you do not need to change the global xcode-select setting." >&2
            exit 2
          fi

          if [ ! -d "$developer_dir" ]; then
            printf '%s\n' \
              "The selected Xcode developer directory does not exist:" \
              "  $developer_dir" \
              "Fix DEVELOPER_DIR or install/open Xcode.app, then retry." >&2
            exit 2
          fi

          # Xcode 26/macOS 26 can ship the Metal toolchain as an on-demand
          # component. If Metal is absent, try the documented component install
          # automatically because this command is already an explicit bootstrap.
          if ! /usr/bin/xcrun --find metal >/dev/null 2>&1; then
            darwin_major="$(uname -r | cut -d. -f1)"
            if [ "$darwin_major" -ge 25 ]; then
              echo "Metal is not available from the selected Xcode."
              echo "Attempting to install Xcode's MetalToolchain component..."
              if /usr/bin/xcodebuild -downloadComponent MetalToolchain; then
                echo "MetalToolchain component download completed."
              else
                echo "Automatic MetalToolchain component installation did not complete." >&2
              fi
              echo
            fi
          fi

          if ! /usr/bin/xcrun --find metal >/dev/null 2>&1; then
            printf '%s\n' \
              "Zed's macOS build requires the Xcode Metal toolchain, but 'metal' is still unavailable." \
              "Developer directory used by this bootstrap:" \
              "  $developer_dir" \
              "" \
              "Finish Xcode setup, then retry:" \
              "  sudo xcodebuild -runFirstLaunch" \
              "  sudo xcodebuild -license accept" \
              "" \
              "On macOS 26, if needed, also run:" \
              "  xcodebuild -downloadComponent MetalToolchain" \
              "" \
              "Then rerun:" \
              "  rh-zed-eval-bootstrap" >&2
            exit 2
          fi

          echo "Xcode developer directory: $developer_dir"
          echo "Metal compiler: $(/usr/bin/xcrun --find metal)"

          sdk_path="$(/usr/bin/xcrun --show-sdk-path)"
          export BINDGEN_EXTRA_CLANG_ARGS="--sysroot=$sdk_path"

          mkdir -p "$root" "$bin_dir"

          if [ ! -d "$source_dir/.git" ]; then
            if [ -e "$source_dir" ]; then
              echo "Expected a managed Git checkout at $source_dir, but another file exists there." >&2
              exit 3
            fi
            echo "Cloning Zed source into:"
            echo "  $source_dir"
            git clone --filter=blob:none --no-checkout \
              https://github.com/zed-industries/zed.git \
              "$source_dir"
          fi

          echo "Fetching audited Zed source pin: $pin"
          git -C "$source_dir" fetch --depth 1 origin "$pin"
          git -C "$source_dir" checkout --detach "$pin"

          actual="$(git -C "$source_dir" rev-parse HEAD)"
          if [ "$actual" != "$pin" ]; then
            echo "Zed source verification failed: expected $pin, got $actual" >&2
            exit 3
          fi

          if [ -n "$(git -C "$source_dir" status --porcelain --untracked-files=no)" ]; then
            echo "Managed Zed checkout has tracked modifications; refusing to build it." >&2
            echo "Remove $root and rerun rh-zed-eval-bootstrap, or restore the checkout first." >&2
            exit 3
          fi

          echo "Installing Rust toolchain $toolchain with rustup..."
          rustup toolchain install "$toolchain" --profile minimal

          echo "Building eval-cli from Zed $pin..."
          (
            cd "$source_dir"
            rustup run "$toolchain" cargo build -p eval_cli --release
          )

          install -m 0755 "$source_dir/target/release/eval-cli" "$eval_cli"

          echo
          echo "eval-cli installed:"
          echo "  $eval_cli"
          echo "source pin: $actual"
          echo "rust toolchain: $toolchain"
          echo "Xcode developer directory: $developer_dir"
          echo
          echo "Verify with:"
          echo "  rh-zed-eval-check"
          echo
          echo "Use from a repo-harness source checkout with:"
          echo '  EVAL_CLI="$(rh-zed-eval-path)"'
          echo '  bun src/cli/index.ts zed-eval --binary "$EVAL_CLI" --workdir "$(pwd -P)" ...'
        '';
      };

      zedEvalPath = pkgs.writeShellApplication {
        name = "repo-harness-zed-eval-path";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          set -euo pipefail

          data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
          eval_cli="$data_home/repo-harness/zed-eval/${zedEvalPinnedCommit}/bin/eval-cli"

          if [ ! -x "$eval_cli" ]; then
            echo "eval-cli is not installed for the repo-harness audited pin." >&2
            echo "Run: rh-zed-eval-bootstrap" >&2
            exit 127
          fi

          printf '%s\n' "$eval_cli"
        '';
      };

      zedEvalCheck = pkgs.writeShellApplication {
        name = "repo-harness-zed-eval-check";
        runtimeInputs = with pkgs; [
          coreutils
          git
        ];
        text = ''
          set -euo pipefail

          pin="${zedEvalPinnedCommit}"
          data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
          root="$data_home/repo-harness/zed-eval/$pin"
          source_dir="$root/zed"
          eval_cli="$root/bin/eval-cli"

          if [ ! -x "$eval_cli" ]; then
            echo "eval-cli is not installed. Run rh-zed-eval-bootstrap first." >&2
            exit 127
          fi

          if [ ! -d "$source_dir/.git" ]; then
            echo "Pinned Zed source checkout is missing: $source_dir" >&2
            exit 3
          fi

          actual="$(git -C "$source_dir" rev-parse HEAD)"
          if [ "$actual" != "$pin" ]; then
            echo "Zed source pin mismatch: expected $pin, got $actual" >&2
            exit 3
          fi

          echo "eval-cli path: $eval_cli"
          echo "Zed source pin: $actual"
          echo
          "$eval_cli" --help | head -40
        '';
      };
    in
    {
      home.packages = lib.optionals pkgs.stdenv.isDarwin [
        zedEvalBootstrap
        zedEvalPath
        zedEvalCheck
      ];

      home.shellAliases = lib.optionalAttrs pkgs.stdenv.isDarwin {
        rh-zed-eval-bootstrap = "repo-harness-zed-eval-bootstrap";
        rh-zed-eval-path = "repo-harness-zed-eval-path";
        rh-zed-eval-check = "repo-harness-zed-eval-check";
      };
    };
}
