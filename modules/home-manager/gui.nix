{pkgs, ...}: {
  imports = [
    ./sway.nix
  ];

  home.packages = with pkgs; [
    firefox
    okular
    vlc
    drawio
    signal-desktop

    zoom-us
    discord
  ];

  services.dunst.enable = true;
}
