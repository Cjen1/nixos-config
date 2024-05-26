{pkgs, ...}:{
  imports = [
    ./default.nix
  ];

  environment.systemPackages = with pkgs; [
    jellyfin-web
  ];

  virtualisation.arion.projects."jellyfin".settings = {
    services."jellyfin".service = {
      image = "jellyfin/jellyfin";
      restart = "unless-stopped";
      user = "846:846";

      volumes = [
        "/persist/jellyfin/cache:/cache"
        "/persist/jellyfin/config:/cache"
        "/persist/jellyfin/media:/media"
      ];

      ports = [
        "8096:8096/tcp"
      ];
    };
  };
}
