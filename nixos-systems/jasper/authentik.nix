{...}:{
  imports = [
    ../../modules/nixos/docker-services
  ];

  virtualisation.arion.projects."authentik".settings = {
    services."authentik".service = {
      image = "";
      restart = "unless-stopped";

      
    };
  };
}
