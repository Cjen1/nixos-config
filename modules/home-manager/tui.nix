{ lib, pkgs, leanNixpkgs ? null, ... }:
let
  lean4 =
    if leanNixpkgs == null then pkgs.lean4
    else leanNixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.leanPackages.lean4;
in
{
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
    (lib.lowPrio elan)
    lean4
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
    bubblewrap
    ripgrep
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
