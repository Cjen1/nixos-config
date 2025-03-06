{ inputs, pkgs, lib, config, unstable, ... }: {
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    ../../modules/nixos/greetd.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/polkit.nix

    # Services
    ./jellyfin.nix
    ./grist.nix
    ./wedding-rsvp
    #./deluge.nix
    ./calibre.nix
    #./radarr/docker-compose.nix
    ./audiobookshelf.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix = {
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}")
      config.nix.registry;

    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };
  };

  time.timeZone = "Europe/London";

  # ZFS
  boot.supportedFilesystems = [ "zfs" ];
  boot.kernelPackages = pkgs.zfs.latestCompatibleLinuxPackages;
  services.zfs.autoScrub.enable = true;
  boot.zfs.extraPools = [ "tank" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "jasper"; # Define your hostname.
  networking.hostId = "72eb5fa0"; # HostID for zfs

  networking.networkmanager.enable = true;

  hardware.graphics = {
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
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    dina-font
    proggyfonts
    libertine
    nerd-fonts.hack
  ];

  environment.systemPackages = with pkgs; [
    vim
    networkmanager
    pavucontrol
    brightnessctl
    arion
    docker-client
    htop
    inputs.agenix.packages.${system}.default
    #beets
  ];

  virtualisation.docker.enable = true;
  services.udisks2.enable = true;

  security.sudo.wheelNeedsPassword = false;
  programs.fish.enable = true;
  programs.light.enable = true;
  users.users.cjen1 = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "audio"
      "video"
      "pulse-access"
      "docker"
      "adbusers"
    ]; # Enable ‘sudo’ for the user.
  };

  home-manager = let
    wayland_display_config = {
      #"eDP-1" = {
      #  pos = "0 1157";
      #  scale = "1.5";
      #};
    };
  in {
    extraSpecialArgs = { inherit inputs wayland_display_config unstable; };
    users = { cjen1 = import ../../home-manager/jasper; };
  };
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-wlr xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };
  users.users."cjen1".openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDEPav2s9tR5yIY6eeaGlag9YAC0HFoj/Lc0iNq2MvcIhvEC81fPHXg1Ie/s2ZykHofGo0EeN92kn3Rl3cflO9n9G5mLxZMX4ABFARO6rk2JZbLjPI1BFZ4CiayFMUaPkT6Ogx2ByWUQkY5WaTJsJHYV/d97ZTzQ0JDSKhcpgLqbiiioJ4I6N1gIMy4cIx84e3FSy/eW78FoBlEMoLVCyNcTaN7HGRT00AuENUTepTnzNcGXFJs34kKm9d3IqAT9zM+k8oK92Ec7nQ7PzkNWt1TY6W4jMXmkyH9yvwvPBQr3QXpnWUTumpksq62pJENTGinesKTYZO7aR+UodBrJ8bqnZXBk/9AG9HG4uYARepggidHzlxcXhjfpTFiHtFSD8OnMUAkcN6jy3YjiZTL5FV/84rPiye5iPpIZviOm/7V2Mt2YeOKThJ/rTcjmI6ZOuzlO9WM9QyZ9c9EL2//cho+4LrFWKleYR/todXyUZbh5LztV7dQYNZZUCIXTkEmA8k= cjen1@shale"
  ];

  # ---- Services ----
  services.caddy = {
    enable = true;
    dataDir = "/data/caddy/data";
    logDir = "/data/caddy/log";
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Jellyfin - remainder is configured as in jellyfin.nix
  services.caddy.virtualHosts = {
    "jellyfin.jentek.dev".extraConfig = ''
      reverse_proxy 127.0.0.1:8096
    '';
    "rsvp.jensenking.com".extraConfig = ''
      @cors_preflight {
        method OPTIONS
      }
      respond @cors_preflight 204

      header {
          Access-Control-Allow-Origin *
          Access-Control-Allow-Methods GET,POST,OPTIONS,HEAD,PATCH,PUT,DELETE
          Access-Control-Allow-Headers User-Agent,Content-Type,X-Api-Key,X-Requested-With
      }

      reverse_proxy 127.0.0.1:10001
    '';
    "jasper.jentek.dev".extraConfig = ''
      reverse_proxy 127.0.0.1:10002
    '';
    "forester.jentek.dev".extraConfig = ''
      root * /data/forester/output
      file_server {
        index index.xml
      }
    '';
    "ps-todos.jentek.dev".extraConfig = ''
      reverse_proxy 127.0.0.1:5000
    '';
  };

  # Logrotate to minimise log issues
  services.logrotate.enable = true;

  system.stateVersion = "24.05";
}
