{...}: {

  imports = [
    ../../modules/home-manager/tui.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };

  home = {
    username ="cjj39";
    homeDirectory = "/auto/homes/cjj39";
  };

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "23.05";
}
