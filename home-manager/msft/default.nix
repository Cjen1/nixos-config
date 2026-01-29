{...}: {

  imports = [
    ../../modules/home-manager/tui.nix
    ../../modules/home-manager/excalidraw.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };

  home = {
    username ="cjen1-msft";
    homeDirectory = "/home/cjen1-msft";
  };

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "24.11";
}
