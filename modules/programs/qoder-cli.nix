{
  flake.modules.homeManager."qoder-cli" =
    {
      pkgs,
      ...
    }:
    {
      home.packages = [
        pkgs.llm-agents.qoder-cli
      ];
    };
}
