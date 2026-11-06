{ config, lib, pkgs, ... }:
let
  cfg = config.codingAgents.codex;
in
{
  imports = [
    (import ./install-skills.nix {
      agent = "codex";
      target = ".agents/skills";
      # Codex discovers directory symlinks, but skips symlinked SKILL.md files.
      linkSkillDirectories = true;
    })
  ];

  options.codingAgents.codex.instructionsSlug = lib.mkOption {
    type = lib.types.lines;
    default = lib.attrByPath [ "codingAgents" "copilot" "instructionsSlug" ] "" config;
    description = "Host-specific text prepended to the shared Codex instructions; defaults to Copilot's host text.";
  };

  config = {
    home.packages = [
      (pkgs.callPackage ../codex-cli { })
    ];

    home.file.".codex/AGENTS.md" = {
      force = true;
      text =
        lib.optionalString (cfg.instructionsSlug != "") "${cfg.instructionsSlug}\n\n"
        + builtins.readFile ./copilot-instructions.md;
    };
  };
}
