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
        --add-flags "--experimental"
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
  attentionConfig = pkgs.writeText "wmux-attention-config.mjs" ''
    export const hookCommand = ${builtins.toJSON "${wmuxHook}/bin/wmux-copilot-hook"};
    export const dryRun = ${lib.boolToString (cfg.wmuxHooks.attentionExtension == "observe")};
  '';
  attentionExtension = pkgs.runCommand "wmux-attention-extension" { } ''
    mkdir -p "$out"
    cp ${./wmux-attention/extension.mjs} "$out/extension.mjs"
    cp ${./wmux-attention/attention.mjs} "$out/attention.mjs"
    cp ${attentionConfig} "$out/config.mjs"
  '';
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
  options.codingAgents.copilot.wmuxHooks.attentionExtension = lib.mkOption {
    type = lib.types.enum [
      "off"
      "observe"
      "notify"
    ];
    default = "off";
    description = ''
      Experimental permission observer. Observe logs without changing hooks.
      Notify replaces permission-prompt hooks with cancellable delayed alerts.
    '';
  };

  config = {
    assertions = [
      {
        assertion = cfg.wmuxHooks.attentionExtension == "off" || cfg.wmuxHooks.enable;
        message = "wmux attention extension requires codingAgents.copilot.wmuxHooks.enable.";
      }
    ];

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
              matcher =
                if cfg.wmuxHooks.attentionExtension == "notify" then
                  "elicitation_dialog"
                else
                  "permission_prompt|elicitation_dialog";
            }
          )
        ]);
      };

    };

    home.file.".copilot/extensions/wmux-attention" =
      lib.mkIf (cfg.wmuxHooks.attentionExtension != "off") {
        source = attentionExtension;
        recursive = true;
      };
  };
}
