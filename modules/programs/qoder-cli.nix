{
  flake.modules.homeManager."qoder-cli" =
    {
      lib,
      pkgs,
      ...
    }:
    let
      aiTools = import ../../ai-tools { inherit lib; };
      qoderSkillFiles = lib.mapAttrs' (
        name: source:
        lib.nameValuePair ".qoder/skills/${name}" { inherit source; }
      ) aiTools.qoderCli.skills;
    in
    {
      home = {
        packages = [
          pkgs.llm-agents.qoder-cli
        ];

        file = qoderSkillFiles;
      };
    };
}
