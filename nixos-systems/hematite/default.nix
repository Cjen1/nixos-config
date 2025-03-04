{inputs, pkgs, lib, config, unstable, ...}:{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    ../../modules/nixos/greetd.nix
#    ../../modules/nixos/qmk.nix
    ../../modules/nixos/audio.nix
#    ../../modules/nixos/persist.nix

    # Services
    ../../modules/nixos/docker-services/factorio.nix
    ../../modules/nixos/docker-services/jellyfin.nix
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

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  # Usb wifi thingy
  boot.kernelModules = [ "88x2bu" ];
  boot.extraModulePackages = [
    config.boot.kernelPackages.rtl88x2bu
  ];

  networking.hostName = "hematite";
  networking.networkmanager.enable = true;

  hardware.opengl = {
    enable = true;
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
    arion
    docker-client
    htop
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
    extraSpecialArgs = {inherit inputs wayland_display_config unstable; };
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

  security.polkit.enable = true;

  services.openssh = {
    enable= true;
    settings.PasswordAuthentication = false;
  };
  users.users."cjen1".openssh.authorizedKeys.keys = [
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDEPav2s9tR5yIY6eeaGlag9YAC0HFoj/Lc0iNq2MvcIhvEC81fPHXg1Ie/s2ZykHofGo0EeN92kn3Rl3cflO9n9G5mLxZMX4ABFARO6rk2JZbLjPI1BFZ4CiayFMUaPkT6Ogx2ByWUQkY5WaTJsJHYV/d97ZTzQ0JDSKhcpgLqbiiioJ4I6N1gIMy4cIx84e3FSy/eW78FoBlEMoLVCyNcTaN7HGRT00AuENUTepTnzNcGXFJs34kKm9d3IqAT9zM+k8oK92Ec7nQ7PzkNWt1TY6W4jMXmkyH9yvwvPBQr3QXpnWUTumpksq62pJENTGinesKTYZO7aR+UodBrJ8bqnZXBk/9AG9HG4uYARepggidHzlxcXhjfpTFiHtFSD8OnMUAkcN6jy3YjiZTL5FV/84rPiye5iPpIZviOm/7V2Mt2YeOKThJ/rTcjmI6ZOuzlO9WM9QyZ9c9EL2//cho+4LrFWKleYR/todXyUZbh5LztV7dQYNZZUCIXTkEmA8k= cjen1@shale"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOeHK5WOR8Yyt6bj9cBOmBshsGfulZC0czWufimgALzc cjen1@jasper"
  ];

  system.stateVersion = "23.11";
}
