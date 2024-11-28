{inputs, config, ...}:{
  imports = [
    ../../secrets
    ./gluetun.nix
  ];
  
  #virtualisation.arion.projects."deluge".settings = {
  #  services."deluge".service = {
  #    image = "lscr.io/linuxserver/deluge:latest";
  #    restart = "unless-stopped";

  #    environment.PUID=1000;
  #    environment.PGID=100;

  #    volumes = [
  #      "/data/media:/media"
  #      "/data/deluge/config:/config"
  #    ];

  #    ports = [
  #      "8112:8112"
  #      "6881:6881"
  #      "
  #    ];

  #  };
  #};
}
