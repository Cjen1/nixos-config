{inputs, lib, config, pkgs, ...}: {

  imports = [
    ../../modules/home-manager/tui.nix
    ../../modules/home-manager/gui.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };

  home = {
    username ="cjen1";
    homeDirectory = "/home/cjen1";
  };

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "23.05";
}
