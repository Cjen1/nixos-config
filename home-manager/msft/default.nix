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

  programs.bash = {
    enable = true;
    bashrcExtra = ''
      if [ -r /etc/bash.bashrc ]; then
        . /etc/bash.bashrc
      fi
      if [ -r "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi
      if [ -r "$HOME/.profile" ]; then
        . "$HOME/.profile"
      fi
    '';
  };

  programs.neovim = {
    withPython3 = true;
    withRuby = true;
  };

  programs.home-manager.enable = true;

  home.file = {
    ".bash_profile".force = true;
    ".bashrc".force = true;
    ".profile".force = true;
  };

  home.stateVersion = "24.11";
}
