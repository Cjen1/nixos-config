{...}:{
  imports = [
    ../../modules/nixos/docker-services
  ];

#  virtualisation.oci-containers = {
#    containers.grist = {
#      image = "gristlabs/grist:stable";
#      ports = ["8484:8484/tcp"];
#      volumes = ["/data/grist:/persist"];
#      environment.GRIST_SESSION_SECRET="1234";
#    };
#  };

  virtualisation.arion.projects."grist".settings = {
    services."grist".service = {
      image = "gristlabs/grist:stable";
      restart = "unless-stopped";

      environment.GRIST_SESSION_SECRET = "1234";
      volumes = [
        "/data/grist:/persist"
      ];
      ports = ["8484:8484/tcp"];
    };
  };

}
