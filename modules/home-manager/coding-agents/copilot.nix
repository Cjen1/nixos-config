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
  wmuxHook = pkgs.writeShellApplication {
    name = "wmux-copilot-hook";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.tmux
    ];
    text = builtins.readFile ./wmux-copilot-hook.sh;
  };
  wmuxEvents = [
    "userPromptSubmitted"
    "preToolUse"
    "agentStop"
    "subagentStart"
    "subagentStop"
    "notification"
    "errorOccurred"
    "sessionEnd"
  ];
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
  options.codingAgents.copilot.wmuxHooks.enable =
    lib.mkEnableOption "Copilot status and notification hooks for wmux terminals";

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

    home.file.".copilot/hooks/wmux.json" = lib.mkIf cfg.wmuxHooks.enable {
      text = builtins.toJSON {
        version = 1;
        hooks = lib.genAttrs wmuxEvents (event: [
          (
            {
              type = "command";
              bash = "${wmuxHook}/bin/wmux-copilot-hook ${event}";
              timeoutSec = 2;
            }
            // lib.optionalAttrs (event == "notification") {
              matcher = "permission_prompt|elicitation_dialog";
            }
          )
        ]);
      };
    };
  };
}
