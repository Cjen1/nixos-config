{pkgs, lib, ...}: {
  imports = [
    ./alacritty.nix
  ];
  wayland.windowManager.sway = let
    modifier = "Mod4";
  in {
    enable = true;
    config = {
      modifier = modifier;
      terminal = "alacritty";
      menu = "fuzzel";
      gaps.smartBorders = "on";
      gaps.smartGaps = true;
      keybindings = lib.mkOptionDefault {
        # Brightness
        "XF86MonBrightnessDown" = "exec light -U 10";
        "XF86MonBrightnessUP"   = "exec light -A 10";

        # Volume
        "XF86AudioRaiseVolume" = "exec 'wpctl set-volume @DEFAULT_SINK@ 0.1+'";
        "XF86AudioLowerVolume" = "exec 'wpctl set-volume @DEFAULT_SINK@ 0.1-'";
        "XF86AudioMute" = "exec 'wpctl set-mute @DEFAULT_SINK@ toggle'";
      };
    };
    extraConfig = ''
    input "type:touchpad" {
      tap enabled
    }
    '';
  };

  programs.fuzzel.enable= true;

  home.packages = [
    (
      pkgs.makeDesktopItem {
        name = "shutdown-now";
        desktopName = "shutdown now";
        exec = "shutdown 0";
        terminal = true;
      }
    )
  ];
}
