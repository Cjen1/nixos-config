{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codingAgents.copilot;
  copilot = pkgs.callPackage ../github-copilot-cli { };
  copilotWithDefaults = pkgs.symlinkJoin {
    name = "github-copilot-cli-with-defaults";
    paths = [ copilot ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/copilot" \
        --unset COPILOT_ALLOW_ALL \
        --add-flags --experimental
    '';
  };
  skills = {
    source = ./copilot-skills;
    recursive = true;
    force = true;
  };
in
{
  options.codingAgents.copilot.instructionsSlug = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Host-specific text prepended to the shared Copilot instructions.";
  };

  config = {
    home.packages = [
      copilotWithDefaults
    ];

    home.file = {
      ".agents/skills" = skills;
      ".claude/skills" = skills;
      ".copilot/copilot-instructions.md" = {
        force = true;
        text =
          lib.optionalString (cfg.instructionsSlug != "") "${cfg.instructionsSlug}\n\n"
          + builtins.readFile ./copilot-instructions.md;
      };
      ".copilot/skills" = skills;
    };

    home.activation.removeLegacySkillSymlinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      for path in "$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.copilot/skills"; do
        if [ -L "$path" ]; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$path"
        fi
      done
    '';
  };
}
