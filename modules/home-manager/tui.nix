{pkgs, ...}: {
  imports = [
    ./git.nix
    ./neovim
    ./scripts.nix
  ];

  home.sessionVariables = {
    EDITOR = "vim";
  };

  home.packages = with pkgs; [
    gnumake
    tmux
    unzip
    magic-wormhole
    usbutils
    pciutils
    htop
    reflex
    jq
    viddy
    krb5
    fzf
    dig
    opencode
    (pkgs.callPackage ./codex-cli { })
    (pkgs.callPackage ./github-copilot-cli { })
  ];

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    flags = [
      "--disable-up-arrow"
    ];
  };
  
  programs.fish = {
    enable = true;
    shellInit = ''
      direnv hook fish | source
    '';
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };
}
