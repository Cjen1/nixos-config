{inputs, pkgs, lib, config, unstable, ...}:{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-hardware.nixosModules.framework-13th-gen-intel
    ../../modules/nixos/greetd.nix
    ../../modules/nixos/cam-vpn
    ../../modules/nixos/cam-vpn/desktop_items.nix
    ../../modules/nixos/qmk.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/bluetooth.nix
    ../../modules/nixos/cambridge.nix
    ../../modules/nixos/persist.nix
    ../../modules/nixos/polkit.nix
  ];

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
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mercury";
  networking.networkmanager.enable = true;
  #boot.extraModprobeConfig = ''
  #  options iwlwifi 11n_disable=8
  #'';

  hardware.opengl = {
    enable = true;
    driSupport = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    dina-font
    proggyfonts
    libertine
    (nerdfonts.override { fonts = [ "Hack" ]; })
  ];

  environment.systemPackages = 
    with pkgs; [
    vim 
    networkmanager
    pavucontrol
    brightnessctl
  ];

  programs.steam.enable = true;

  virtualisation.docker.enable = true;
  services.udisks2.enable = true;

  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;
  programs.light.enable = true;
  users.users.cjen1 = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" "pulse-access" "docker" "adbusers" ]; # Enable ‘sudo’ for the user.
  };

  home-manager = 
  let wayland_display_config = {
    "eDP-1" = {
      pos = "0 1157";
      scale = "1";
    };
  };
  in
  {
    extraSpecialArgs = {inherit inputs wayland_display_config unstable; };
    users = {
      cjen1 = import ../../home-manager/graphite;
    };
  };
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };

  # framework firmware upgrade
  services.fwupd.enable = true;

  # use suspend-then-hibernate on lid close
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=3600s
    SuspendState=mem
  '';
  services.logind.lidSwitch="suspend-then-hibernate";
  services.logind.powerKey="suspend-then-hibernate";
  services.logind.powerKeyLongPress="poweroff";

  system.stateVersion = "23.10";
}
