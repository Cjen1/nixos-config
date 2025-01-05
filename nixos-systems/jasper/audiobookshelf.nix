{...}:{
  imports = [
    ../../modules/nixos/docker-services
  ]; 

  virtualisation.arion.projects."audiobookshelf".settings = {
    services."audiobookshelf".service = {
      image = "ghcr.io/advplyr/audiobookshelf:latest";
      restart = "unless-stopped";

      environment.PUID=1003;
      environment.PGID=1003;
      user = "1003:1003";

      volumes = [
        "/data/media/audiobookshelf/books:/audiobooks"
        "/data/media/audiobookshelf/config:/config"
        "/data/media/audiobookshelf/metadata:/metadata"
      ];
      ports = [
        "10004:80"
      ];
    };
  };
  services.caddy.virtualHosts."audiobookshelf.jentek.dev".extraConfig = ''
    reverse_proxy 127.0.0.1:10004
  '';
}
