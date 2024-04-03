{inputs, pkgs, lib, config, ...}:{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
#    inputs.nixos-hardware.nixosModules.framework-13th-gen-intel
    ../../modules/nixos/greetd.nix
#    ../../modules/nixos/cam-vpn
#    ../../modules/nixos/cam-vpn/desktop_items.nix
#    ../../modules/nixos/qmk.nix
    ../../modules/nixos/audio.nix
#    ../../modules/nixos/bluetooth.nix
#    ../../modules/nixos/cambridge.nix
    ../../modules/nixos/persist.nix
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

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;
  boot.kernelModules = [ "88x2bu" ];
  boot.extraModulePackages = [
    config.boot.kernelPackages.rtl88x2bu
  ];

  networking.hostName = "hematite";
  networking.networkmanager.enable = true;

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
    #"eDP-1" = {
    #  pos = "0 1157";
    #  scale = "1.5";
    #};
  };
  in
  {
    extraSpecialArgs = {inherit inputs wayland_display_config; };
    users = {
      cjen1 = import ../../home-manager/hematite;
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

  # set keymap
  services.xserver = {
    layout = "gb";
    xkbVariant = "";
  };
  console.keyMap = "uk";

  security.polkit.enable = true;

  system.stateVersion = "23.11";
}
