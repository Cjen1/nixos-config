{pkgs, unstable, ...}: {
  imports = [
    ./sway.nix
  ];

  home.packages = with pkgs; [
    firefox
    okular
    vlc
    drawio
    unstable.signal-desktop
    zathura

    zoom-us
    discord
  ];

  services.dunst.enable = true;
}
