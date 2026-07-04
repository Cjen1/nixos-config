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
    ../../modules/nixos/cpufreq.nix
    ../../modules/nixos/tailscale.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [ ];

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

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  fonts.enableDefaultPackages = true;
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    dina-font
    proggyfonts
    libertine
    nerd-fonts.hack

    pkgs.cm_unicode
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
  users.users.cjen1 = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ 
      "wheel" 
      "audio" 
      "video" 
      "pulse-access" 
      "adbusers"
      "dialout"
      ]; # Enable ‘sudo’ for the user.
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
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "3600s";
    SuspendState = "mem";
  };
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandlePowerKey = "suspend-then-hibernate";
    HandlePowerKeyLongPress = "poweroff";
  };

  system.stateVersion = "23.10";
}
