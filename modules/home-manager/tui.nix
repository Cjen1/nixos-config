{
  pkgs,
  t3CodePackage ? pkgs.callPackage ./t3-code { },
  ...
}: {
  imports = [
    ./git.nix
    ./neovim
    ./scripts.nix
  ];

  home.sessionVariables = {
    EDITOR = "vim";
  };

  home.packages = with pkgs; [
    atuin
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
    (pkgs.callPackage ./opencode-cli { })
    (pkgs.callPackage ./codex-cli { })
    (pkgs.callPackage ./github-copilot-cli { })
    t3CodePackage
    nodejs_26
  ];
  
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
