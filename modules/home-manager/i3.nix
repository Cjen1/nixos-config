{
  pkgs,
  lib,
  ...
}: {
  xsession = {
    enable = true;
    scriptPath = ".hm-xsession";
    windowManager.i3 = let
      modifier = "Mod4";
    in {
      enable = true;
      package = pkgs.i3-gaps;
      config = {
        modifier = "${modifier}";
        focus.mouseWarping = false;
        gaps = {
          smartBorders = "on";
          smartGaps = true;
          inner = 12;
        };
        keybindings = lib.mkOptionDefault {
          "XF86AudioPlay" = "exec tmux send-keys -t spt.0 space";
          "XF86AudioPause" = "exec tmux send-keys -t spt.0 space";
          "XF86AudioNext" = "exec tmux send-keys -t spt.0 n";
          "XF86AudioPrev" = "exec tmux send-keys -t spt.0 p";
          "${modifier}+d" = builtins.concatStringsSep " " [
            "exec --no-startup-id"
            "rofi -show run"
          ];
        };
        startup = [
          {
            command = "tmux new -d -s spt spt";
            always = true;
          }
        ];
        terminal = "alacritty";
      };
    };
  };

  programs.rofi = {
    enable = true;
    location = "top";
  };
}
