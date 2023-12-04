{inputs, ...}:{
  imports = [
    inputs.arion.nixosModules.arion
  ];

  virtualisation.arion.backend = "docker";

  virtualisation.arion.projects."factorio".settings = {
    services."factorio".service = {
      image = "factoriotools/factorio:stable";
      restart = "unless-stopped";
      ports = [
        "34197:34197/udp"
      ];
      volumes = [ "/persist/factorio:/factorio" ];
    };
  };
}
