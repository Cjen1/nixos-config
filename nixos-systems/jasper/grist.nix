{...}:{
  imports = [
    ../../modules/nixos/docker-services
  ];

  virtualisation.arion.projects."grist".settings = {
    services."grist".service = {
      image = "gristlabs/grist:stable";
      restart = "unless-stopped";

      environment = {
      };
      
      volumes = [
        "/data/grist:/persist"
      ];

      ports = [
        "8484:8484/tcp"
      ];
    };
  };

}
