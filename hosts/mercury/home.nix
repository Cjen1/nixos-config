{ ... }:
{
  imports = [
    ../../modules/home-manager/tui.nix
    ../../modules/home-manager/gui.nix
    ../../modules/home-manager/coding-agents/opencode.nix
    ../../modules/home-manager/coding-agents/codex.nix
    ../../modules/home-manager/coding-agents/copilot.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  home = {
    username = "cjen1";
    homeDirectory = "/home/cjen1";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
  systemd.user.startServices = "sd-switch";
}
