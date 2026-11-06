{ unstable, ... }: {

  imports = [
    ../../modules/home-manager/tui.nix
    ../../modules/home-manager/coding-agents/opencode.nix
    ../../modules/home-manager/coding-agents/codex.nix
    ../../modules/home-manager/coding-agents/copilot.nix
#    ../../modules/home-manager/gui.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };

  home = {
    username ="cjen1";
    homeDirectory = "/home/cjen1";
    packages = [ unstable.t3code ];
  };

  programs.home-manager.enable = true;

  # Temporary T3 service for remote configuration cleanup.
  systemd.user.services.t3code = {
    Unit.Description = "T3 Code server";
    Service = {
      ExecStart = "${unstable.t3code}/bin/t3 serve --host 127.0.0.1 --port 3773";
      WorkingDirectory = "/home/cjen1/repos/nixos-config";
      Environment = "PATH=/home/cjen1/.nix-profile/bin:/etc/profiles/per-user/cjen1/bin:/run/current-system/sw/bin";
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.startServices = "sd-switch";

  #home.file.".ssh" = {
  #  source = /persist/secrets;
  #  recursive = true;
  #};

  home.stateVersion = "26.05";
}
