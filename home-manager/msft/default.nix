{pkgs, ...}: {

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

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  programs.git.settings = {
    http.sslCAInfo = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    diff.tool = "vscode";
    difftool.vscode.cmd = "code --wait --diff \"$LOCAL\" \"$REMOTE\"";
  };

  programs.neovim = {
    withPython3 = true;
    withRuby = true;
  };

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";
}
