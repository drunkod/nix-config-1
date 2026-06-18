{ pkgs }:
let
  python = pkgs.python311;

  graphifyWrapper = pkgs.writeShellScriptBin "graphify" ''
    export AWS_DEFAULT_REGION="us-gov-west-1"
    exec ${python}/bin/python -m graphify.cli "$@"
  '';

  mkGraphifyApp =
    name: script:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        graphifyWrapper
        python
      ];
      text = script;
    };
in
{
  apps = {
    graphify = mkGraphifyApp "graphify" ''
      exec ${graphifyWrapper}/bin/graphify "$@"
    '';

    extract = mkGraphifyApp "graphify-extract" ''
      target="''${1:-.}"
      exec graphify extract "$target" --no-cluster
    '';

    update = mkGraphifyApp "graphify-update" ''
      target="''${1:-.}"
      exec graphify extract "$target" --no-cluster
    '';

    query = mkGraphifyApp "graphify-query" ''
      exec graphify query "$@"
    '';

    mcp = mkGraphifyApp "graphify-mcp" ''
      exec graphify mcp "$@"
    '';

    test = mkGraphifyApp "graphify-test" ''
      exec graphify test "$@"
    '';

    skill = mkGraphifyApp "graphify-skill" ''
      exec graphify skill "$@"
    '';
  };

  packages = {
    graphify = graphifyWrapper;
    skill = graphifyWrapper;
    default = graphifyWrapper;
  };

  devShells.default = pkgs.mkShell {
    packages = [
      graphifyWrapper
      python
    ];
  };

  checks.skill = pkgs.runCommand "graphify-skill-check" { } ''
    mkdir -p $out
  '';
}
