{
  lib,
  python3,
  fetchPypi,
  versionCheckHomeHook ? null,
  ...
}:

let
  python = python3;
in
python.pkgs.buildPythonApplication rec {
  pname = "graphifyy";
  version = "0.8.39";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-eeIG/SHeCQv3FV8KxGE0V5UpXtyDfpDpvMgslhpjE6c=";
  };

  build-system = with python.pkgs; [
    setuptools
  ];

  pypaBuildFlags = [
    "--skip-dependency-check"
  ];

  dependencies = with python.pkgs; [
    networkx
    numpy
    rapidfuzz
    tree-sitter
    tree-sitter-python
    tree-sitter-javascript
    tree-sitter-rust
    tree-sitter-c-sharp
    tree-sitter-bash
    tree-sitter-json
    mcp
  ];

  pythonRelaxDeps = [
    "networkx"
    "numpy"
    "rapidfuzz"
    "tree-sitter"
    "tree-sitter-python"
    "tree-sitter-javascript"
    "tree-sitter-rust"
    "tree-sitter-c-sharp"
    "tree-sitter-bash"
    "tree-sitter-json"
  ];

  pythonImportsCheck = [
    "graphify"
    "graphify.__main__"
  ];

  doInstallCheck = true;

  nativeInstallCheckInputs = lib.optional (versionCheckHomeHook != null) versionCheckHomeHook;

  installCheckPhase = ''
    runHook preInstallCheck

    $out/bin/graphify --version | grep ${version}
    $out/bin/graphify --help >/dev/null

    test -x $out/bin/graphify-mcp

    runHook postInstallCheck
  '';

  passthru.category = "Memory & Code Intelligence";

  meta = with lib; {
    description = "AI coding assistant skill that turns codebases into a queryable knowledge graph";
    longDescription = ''
      Graphify maps a project into graphify-out/graph.json,
      GRAPH_REPORT.md, and graph.html. This Nix package intentionally ships
      the base code-oriented runtime plus the MCP entry point, while avoiding
      AI-provider and document/media extraction extras such as openai,
      anthropic, gemini, ollama, pdf, office, video, and all.

      For strict local use, run Graphify against a code-only corpus and use
      .graphifyignore to exclude docs, PDFs, images, media, and other files
      that would require semantic extraction.
    '';
    homepage = "https://github.com/safishamsi/graphify";
    changelog = "https://github.com/safishamsi/graphify/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "graphify";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
