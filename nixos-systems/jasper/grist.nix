{...}:{
  imports = [
    ../../modules/nixos/docker-services
  ];

  virtualisation.arion.projects."grist".settings = {
    services."grist".service = {
      image = "gristlabs/grist:stable";
      restart = "unless-stopped";

      environment = {
        GRIST_SESSION_SECRET="1234";
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
