{ lib, pkgs, ... }:
let
  skills = {
    source = ./copilot-skills;
    recursive = true;
    force = true;
  };
in
{
  home.packages = [
    (pkgs.callPackage ../github-copilot-cli { })
  ];

  home.file = {
    ".agents/skills" = skills;
    ".claude/skills" = skills;
    ".copilot/skills" = skills;
  };

  home.activation.removeLegacySkillSymlinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for path in "$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.copilot/skills"; do
      if [ -L "$path" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$path"
      fi
    done
  '';
}
