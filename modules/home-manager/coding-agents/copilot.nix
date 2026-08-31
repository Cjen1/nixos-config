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
in
{
  imports = [
    (import ./install-skills.nix {
      agent = "copilot";
      target = ".copilot/skills";
    })
  ];

  options.codingAgents.copilot.instructionsSlug = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Host-specific text prepended to the shared Copilot instructions.";
  };

  config = {
    home.packages = [
      copilotWithDefaults
    ];

    home.file.".copilot/copilot-instructions.md" = {
      force = true;
      text =
        lib.optionalString (cfg.instructionsSlug != "") "${cfg.instructionsSlug}\n\n"
        + builtins.readFile ./copilot-instructions.md;
    };
  };
}
