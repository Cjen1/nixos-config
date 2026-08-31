{
  agent,
  target,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codingAgents.${agent};
in
{
  options.codingAgents.${agent}.installSkills = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the shared skills for ${agent}.";
  };

  config = lib.mkIf cfg.installSkills {
    home.file.${target} = {
      source = ./copilot-skills;
      recursive = true;
      force = true;
    };

    home.activation."removeLegacy${agent}SkillSymlink" =
      lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ -L "$HOME/${target}" ]; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$HOME/${target}"
        fi
      '';
  };
}
