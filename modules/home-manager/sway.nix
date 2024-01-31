{pkgs, lib, wayland_display_config, ...}: {
  imports = [
    ./alacritty.nix
  ];
  wayland.windowManager.sway = let
  sway-scripts = import ../../scripts/sway-scripts.nix {inherit pkgs;};
  in rec {
    enable = true;
    config = {
      modifier = "Mod4";
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

        # Screenshotting
        "${config.modifier}+Shift+s" = "exec ${sway-scripts.screenshot}/bin/sway-screenshot";
      };
      output = wayland_display_config;
    };
    extraConfig = ''
    input "type:touchpad" {
      tap enabled
      dwt disabled
    }
    '';
  };

  programs.fuzzel.enable= true;

  home.packages = [
    pkgs.wl-clipboard
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
