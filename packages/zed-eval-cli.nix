{
  lib,
  rustPlatform,
  stdenv,
  fetchFromGitHub,
  apple-sdk_15,
  cmake,
  libiconv,
  pkg-config,
  ...
}:
rustPlatform.buildRustPackage {
  pname = "zed-eval-cli";
  version = "24e25552";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "zed";
    rev = "24e25552b1259d56a6fdd7956a419ed9e8a1a25e";
    hash = "sha256-feeCPG7SU3mfLrsLLleTuBvDWP40DbGAbcJ6lAqdt34=";
  };

  # Zed eval-cli at the pinned revision emits an extra literal quote after
  # its generated settings JSON, causing:
  # "Failed to migrate settings: trailing characters".
  # Remove only that trailing quote until the upstream source is fixed.
  postPatch = ''
    substituteInPlace crates/eval_cli/src/main.rs \
      --replace-fail \
        '                }}"' \
        '                }}'
  '';

  cargoHash = "sha256-grkBBo4B7tYasxZc5a0WSibaz+ZpZK+yomne+9Lb//Q=";
  cargoBuildFlags = [
    "--locked"
    "-p"
    "eval_cli"
    "--features"
    "gpui_platform/runtime_shaders"
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    apple-sdk_15
    libiconv
  ];

  doCheck = false;
  dontCargoInstall = true;

  postInstall = ''
    install -Dm755 \
      "target/${stdenv.hostPlatform.rust.rustcTarget}/release/eval-cli" \
      "$out/bin/eval-cli"
  '';

  meta = {
    description = "Zed's headless agent evaluation CLI";
    homepage = "https://github.com/zed-industries/zed";
    license = lib.licenses.gpl3Only;
    mainProgram = "eval-cli";
    platforms = lib.platforms.darwin;
  };
}
