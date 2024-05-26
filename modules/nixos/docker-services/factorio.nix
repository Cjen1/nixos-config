{...}:{
  imports = [
    ./default.nix
  ];

  virtualisation.arion.projects."factorio".settings = {
    services."factorio".service = {
      image = "factoriotools/factorio:1.1.100";
      restart = "unless-stopped";
      ports = [
        "34197:34197/udp"
      ];
      volumes = [ "/persist/factorio:/factorio" ];
    };
  };
}
