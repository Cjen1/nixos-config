{ inputs, pkgs, lib, config, unstable, ... }: {
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    ../../modules/nixos/audio.nix
    ../../modules/nixos/polkit.nix
    ../../modules/nixos/tailscale.nix

    # Services
    ./jellyfin.nix
    #./deluge.nix
    ./calibre.nix
    #./radarr/docker-compose.nix
    ./audiobookshelf.nix
    ./immich.nix
    ./audiomuse-ai.nix
    ./dex.nix
    ./ps-todos.nix
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
  #boot.kernelPackages = pkgs.zfs.linuxPackages;
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
      intel-vaapi-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
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
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

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
    package = unstable.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-hEHgAG0F0ozHRAPuxEqLyTATBrE+pajeXDiSNwniorg=";
    };
    dataDir = "/data/caddy/data";
    logDir = "/data/caddy/log";
    environmentFile = config.age.secrets."cloudflare-caddy-dns-env".path;
  };
  networking.firewall.allowedTCPPorts = [ 80 443 8096 ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 53 ];
  networking.firewall.interfaces.tailscale0.allowedUDPPorts = [ 53 ];

  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      interface = "tailscale0";
      bind-interfaces = true;
      no-resolv = true;
      address = "/ts.jentek.dev/100.96.252.111";
    };
  };

  # Jellyfin - remainder is configured as in jellyfin.nix
  services.caddy.virtualHosts = {
    "jellyfin.jentek.dev".extraConfig = ''
      reverse_proxy 127.0.0.1:8096
    '';
    "todos.jentek.dev".extraConfig = ''
      reverse_proxy 127.0.0.1:5000
    '';
    "http://jellyseerr.ts.jentek.dev".extraConfig = ''
      @notTailnet not remote_ip 100.64.0.0/10 fd7a:115c:a1e0::/48
      respond @notTailnet 403

      reverse_proxy 127.0.0.1:5055
    '';
    "https://*.ts.jentek.dev".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        resolvers 1.1.1.1 8.8.8.8
      }

      @notTailnet not remote_ip 100.64.0.0/10 fd7a:115c:a1e0::/48
      respond @notTailnet 403

      @jellyseerr host jellyseerr.ts.jentek.dev
      handle @jellyseerr {
        reverse_proxy 127.0.0.1:5055
      }

      @radarr host radarr.ts.jentek.dev
      handle @radarr {
        reverse_proxy 127.0.0.1:7878
      }

      @sonarr host sonarr.ts.jentek.dev
      handle @sonarr {
        reverse_proxy 127.0.0.1:8989
      }

      @jackett host jackett.ts.jentek.dev
      handle @jackett {
        reverse_proxy 127.0.0.1:9117
      }

      @transmission host transmission.ts.jentek.dev
      handle @transmission {
        reverse_proxy 127.0.0.1:9091
      }

      @immich host immich.ts.jentek.dev
      handle @immich {
        reverse_proxy 127.0.0.1:2283
      }

      @audiobookshelf host audiobookshelf.ts.jentek.dev
      handle @audiobookshelf {
        reverse_proxy 127.0.0.1:10004
      }

      respond 404
    '';
  };

  # Logrotate to minimise log issues
  services.logrotate.enable = true;

  system.stateVersion = "24.05";
}
