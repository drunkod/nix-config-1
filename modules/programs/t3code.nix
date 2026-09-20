{
  flake.modules.homeManager.t3code =
    {
      pkgs,
      ...
    }:
    {
      home.packages = [
        pkgs.llm-agents.t3code
      ];
    };
}
