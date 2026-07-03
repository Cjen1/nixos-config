{ pkgs, ... }: {
  imports = [
    ./alacritty.nix
  ];

  home.file.".config/niri/config.kdl".text = ''
    include "${pkgs.niri.doc}/share/doc/niri/default-config.kdl"

    prefer-no-csd

    input {
        focus-follows-mouse max-scroll-amount="0%"
    }

    binds {
        Mod+Return hotkey-overlay-title="Open a Terminal: alacritty" { spawn "alacritty"; }

        Mod+F { fullscreen-window; }
        Mod+Shift+P { screenshot; }

        Mod+Shift+Left  { move-column-left; }
        Mod+Shift+Down  { move-window-down; }
        Mod+Shift+Up    { move-window-up; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+H     { move-column-left; }
        Mod+Shift+J     { move-window-down; }
        Mod+Shift+K     { move-window-up; }
        Mod+Shift+L     { move-column-right; }
    }
  '';

  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 28;

      modules-left = [
        "niri/workspaces"
        "niri/window"
      ];
      modules-center = [
        "clock"
      ];
      modules-right = [
        "network"
        "pulseaudio"
        "battery"
        "tray"
      ];

      "niri/workspaces" = {
        format = "{icon}";
        format-icons = {
          active = "●";
          default = "○";
        };
      };

      "niri/window" = {
        format = "{}";
        max-length = 80;
      };

      clock = {
        format = "{:%a %d %b  %H:%M}";
        tooltip-format = "{:%Y-%m-%d}";
      };

      network = {
        format-wifi = "{essid}  {signalStrength}%";
        format-ethernet = "{ifname}";
        format-disconnected = "offline";
        tooltip-format = "{ifname}: {ipaddr}";
      };

      pulseaudio = {
        format = "vol {volume}%";
        format-muted = "muted";
        scroll-step = 5;
      };

      battery = {
        format = "{capacity}%";
        format-charging = "{capacity}% charging";
        states = {
          warning = 30;
          critical = 15;
        };
      };

      tray = {
        spacing = 8;
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: sans-serif;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: #202020;
        color: #eeeeee;
      }

      #workspaces button {
        color: #9a9a9a;
        padding: 0 8px;
      }

      #workspaces button.active {
        color: #ffffff;
        background: #3a3a3a;
      }

      #window,
      #clock,
      #network,
      #pulseaudio,
      #battery,
      #tray {
        padding: 0 10px;
      }

      #battery.warning {
        color: #ffd166;
      }

      #battery.critical {
        color: #ef476f;
      }
    '';
  };

  programs.fuzzel.enable = true;

  home.packages = [
    pkgs.wl-clipboard
    pkgs.swaylock
    pkgs.waybar
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
