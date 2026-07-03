{pkgs, unstable, ...}: {
  imports = [
    ./niri.nix
  ];

  home.packages = with pkgs; [
    firefox
    kdePackages.okular
    vlc
    drawio
    unstable.signal-desktop
    zathura

    zoom-us
    discord
  ];
}
