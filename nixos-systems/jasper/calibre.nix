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
        "/data/calibre/data:/config"
      ];
      ports = [
        "8080:8080"
        "8181:8181"
        "8081:8081"
      ];
    };
  };
}
