{...}:{
  imports = [
    ../../modules/nixos/docker-services
  ]; 

  virtualisation.arion.projects."calibre".settings = {
    services."calibre".service = {
      image = "lscr.io/linuxserver/calibre:latest";
      restart = "unless-stopped";

      environment.PUID=1000;
      environment.PGID=100;

      volumes = [
        "/data/calibre/calibre-config:/config"
        "/data/calibre/backups:/backups"
        "/data/calibre/to-add:/to-add"
      ];
      ports = [
        "8080:8080"
        "8181:8181"
        "8081:8081"
      ];
    };
    services."calibre-web".service = {
      image = "lscr.io/linuxserver/calibre-web:latest";
      restart = "unless-stopped";

      environment.PUID=1000;
      environment.PGID=100;

      environment.DOCKER_MODS="linuxserver/mods:universal-calibre";

      volumes = [
        "/data/calibre/calibre-web-config:/config"
        "/data/calibre/calibre-config/Library:/books"
      ];

      ports = [
        "8083:8083"
      ];
    };
  };
  services.caddy.virtualHosts."calibre-web.jentek.dev".extraConfig = ''
    reverse_proxy 127.0.0.1:8083
  '';
}
