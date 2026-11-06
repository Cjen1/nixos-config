{
  agent,
  target,
  linkSkillDirectories ? false,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codingAgents.${agent};
  skillDirectories = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./copilot-skills)
  );
in
{
  options.codingAgents.${agent}.installSkills = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the shared skills for ${agent}.";
  };

  config = lib.mkIf cfg.installSkills {
    home.file =
      if linkSkillDirectories then
        lib.mapAttrs' (name: _: lib.nameValuePair "${target}/${name}" {
          source = ./copilot-skills + "/${name}";
          force = true;
        }) (builtins.readDir ./copilot-skills)
      else
        {
          ${target} = {
            source = ./copilot-skills;
            recursive = true;
            force = true;
          };
        };

    home.activation."migrate${agent}SkillDirectories" = lib.mkIf linkSkillDirectories (
      lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        skill_backup_dir=""
        for skill in ${lib.escapeShellArgs skillDirectories}; do
          skill_dir="$HOME/${target}/$skill"
          if [ -d "$skill_dir" ] && [ ! -L "$skill_dir" ]; then
            if [[ -v DRY_RUN ]]; then
              echo "Would back up $skill_dir before replacing it with a directory symlink"
            else
              if [ -z "$skill_backup_dir" ]; then
                ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg "${config.xdg.stateHome}/home-manager/skill-migrations"}
                skill_backup_dir="$(${pkgs.coreutils}/bin/mktemp -d ${lib.escapeShellArg "${config.xdg.stateHome}/home-manager/skill-migrations/${agent}.XXXXXX"})"
                echo "Backing up existing ${agent} skill directories to $skill_backup_dir"
              fi
              ${pkgs.coreutils}/bin/mv "$skill_dir" "$skill_backup_dir/$skill"
            fi
          fi
        done
      ''
    );

    home.activation."removeLegacy${agent}SkillSymlink" =
      lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ -L "$HOME/${target}" ]; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$HOME/${target}"
        fi
      '';
  };
}
