{pkgs, ...}: {
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
    };
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
