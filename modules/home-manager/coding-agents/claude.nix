{ config, lib, pkgs, ... }:
let
  cfg = config.codingAgents.claude;
in
{
  imports = [
    (import ./install-skills.nix {
      agent = "claude";
      target = ".claude/skills";
      linkSkillDirectories = true;
    })
  ];

  options.codingAgents.claude.instructionsSlug = lib.mkOption {
    type = lib.types.lines;
    default = lib.attrByPath [ "codingAgents" "copilot" "instructionsSlug" ] "" config;
    description = "Host-specific text prepended to the shared Claude instructions; defaults to Copilot's host text.";
  };

  config = {
    home.packages = [
      (pkgs.callPackage ../claude-code { })
    ];

    home.file.".claude/CLAUDE.md" = {
      force = true;
      text =
        lib.optionalString (cfg.instructionsSlug != "") "${cfg.instructionsSlug}\n\n"
        + builtins.readFile ./copilot-instructions.md;
    };
  };
}
