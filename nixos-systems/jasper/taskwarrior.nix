{pkgs, ...}:{
  imports = [
    ../../modules/nixos/docker-services
  ]; 

  environment.systemPackages = [
    pkgs.taskwarrior3
  ];

  virtualisation.arion.projects."taskwarrior".settings = {
    services."taskwarrior".service = {
      image = "ghcr.io/gothenburgbitfactory/taskchampion-sync-server:main";
      restart = "unless-stopped";

      ports = [
        "8085:8080"
      ];

      volumes = [
        "/data/taskwarrior/taskchampion:/var/lib/taskchampion-sync-server"
      ];
    };
  };

  services.caddy.virtualHosts."taskchampion.jentek.dev".extraConfig = ''
    reverse_proxy 127.0.0.1:8085
  '';
}
