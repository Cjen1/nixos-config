{pkgs, ...}:{
  imports = [
    ./default.nix
  ];

  virtualisation.arion.projects."jellyfin".settings = {
    services."jellyfin".service = {
      image = "jellyfin/jellyfin";
      restart = "unless-stopped";
      user = "cjen1:cjen1";

      volumes = [
        "/persist/jellyfin/cache:/cache"
        "/persist/jellyfin/config:/config"
        "/persist/jellyfin/media:/media"
      ];

      ports = [
        "8096:8096/tcp"
      ];
    };
  };
}
