{
  flake.modules.homeManager.jules =
    {
      pkgs,
      ...
    }:
    {
      home.packages = [
        pkgs.llm-agents.jules
      ];
    };
}
