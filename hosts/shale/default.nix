{inputs, pkgs, lib, config, zotify-dev,...}:{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/ssh-kerberos.nix
    #../../modules/nixos/greetd.nix
    #../../modules/nixos/cam-vpn
    #../../modules/nixos/cam-vpn/desktop_items.nix
    #../../modules/nixos/qmk.nix
    #../../modules/nixos/audio.nix
    #../../modules/nixos/bluetooth.nix
    #../../modules/nixos/cambridge.nix
    #../../modules/nixos/persist.nix
  ];

  wsl.enable = true;
  wsl.defaultUser = "cjen1";
  # Use WSL's existing registration; WSL 3.0.1 makes binfmt_misc read-only.
  wsl.interop.register = false;

  # Allow activation and systemd startup to finish before WSL gives up.
  wsl.wslConf.boot.initTimeout = 60000;

  # WSL's early boot probes run before the normal NixOS PATH is available.
  wsl.extraBin = [
    { src = "${pkgs.systemd}/bin/systemctl"; }
    { src = "${pkgs.gnugrep}/bin/grep"; }
  ];

  # WSL mounts binfmt_misc itself; an automount on it fails during boot.
  systemd.units."proc-sys-fs-binfmt_misc.automount".enable = false;
  systemd.services.systemd-binfmt.enable = false;

  # Manual pages are unused here; avoid building their index at startup.
  documentation.man.enable = false;

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
    ];
  };

  nixpkgs.config.allowUnfree = true;
  nix = {
    registry = lib.mapAttrs (_: value: {flake = value; }) inputs;

    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };
  };

  time.timeZone = "Europe/London";

  networking.hostName = "shale";

  environment.systemPackages =
    with pkgs; [
    vim
    wget
    zotify-dev
  ];

  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;
  users.users.cjen1 = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" "pulse-access" "docker" "adbusers" ]; # Enable ‘sudo’ for the user.
  };

  home-manager.users.cjen1 = import ./home.nix;

  security.polkit.enable = true;

  system.stateVersion = "23.10";
}
