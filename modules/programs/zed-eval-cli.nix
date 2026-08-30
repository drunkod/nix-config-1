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

          if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
            echo "Xcode command line tools are required. Run: xcode-select --install" >&2
            exit 2
          fi

          if ! /usr/bin/xcrun --find metal >/dev/null 2>&1; then
            printf '%s\n' \
              "Zed's macOS build requires the Xcode Metal toolchain." \
              "Install/open full Xcode and select it with:" \
              "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer" \
              "On macOS 26 you may also need:" \
              "  xcodebuild -downloadComponent MetalToolchain" >&2
            exit 2
          fi

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
