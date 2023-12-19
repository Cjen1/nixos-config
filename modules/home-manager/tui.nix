{pkgs, ...}: {
  imports = [
    ./git.nix
    ./neovim
  ];

  home.packages = with pkgs; [
    gnumake
    tmux
    unzip
    magic-wormhole
    usbutils
    pciutils
    htop
    reflex
  ];

  programs.fish = {
    enable = true;
    shellInit = ''
      direnv hook fish | source
    '';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };
}
