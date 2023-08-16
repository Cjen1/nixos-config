{inputs, pkgs, lib, config, ...}:{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad
    ../../modules/nixos/greetd.nix
    ../../modules/nixos/cam-vpn
    ../../modules/nixos/cam-vpn/desktop_items.nix
    ../../modules/nixos/qmk.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/bluetooth.nix
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

  networking.hostName = "graphite";
  networking.networkmanager.enable = true;
  boot.blacklistedKernelModules = [ "snd_pcsp" ];
  boot.extraModprobeConfig = ''
    options iwlwifi 11n_disable=8
  '';
  networking.networkmanager.enableStrongSwan = true;


  services.davfs2.enable = true;

  # vaapi crud 
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };
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

  # Kerberos for cambridge
  krb5 = {
    config = ''
      [libdefaults]
      forwardable = true
      default_realm = DC.CL.CAM.AC.UK
      '';
  };
  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    clientConf = "ServerName cups-serv.cl.cam.ac.uk";
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
    krb5
  ];
  virtualisation.docker.enable = true;
  services.udisks2.enable = true;

  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;
  users.users.cjen1 = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "pulse-access" "docker" "adbusers" ]; # Enable ‘sudo’ for the user.
  };
  home-manager = {
    extraSpecialArgs = {inherit inputs; };
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
  };
  security.polkit.enable = true;

  system.stateVersion = "23.05";
}
