{config, ...}:{
  imports = [
    ../../modules/nixos/docker-services
    ../../secrets
  ];

  virtualisation.arion.projects."gluetun".settings = {
    services."gluetun".service = {
      image = "qmcgaw/gluetun";
      restart = "unless-stopped";

      environment.VPN_SERVICE_PROVIDER = "custom";
      environment.VPN_TYPE="wireguard";
      volumes = [
        "${config.age.secrets."protonvpn-netherlands.wireguard".path}:/gluetun/wireguard/wg0.conf"
      ];
      capabilities = {
        NET_ADMIN = true;
      };
    };
  };
#  virtualisation.oci-containers.containers.gluetun = {
#      image = "qmcgaw/gluetun:";
#      environment = {
#        VPN_SERVICE_PROVIDER = "protonvpn";
#      };
#      volumes = [
#        "${config.age.secrets."protonvpn-netherlands.wireguard".path}:/gluetun/wireguard/wg0.conf"
#      ];
#      extraOptions = [
#        #"--device=/dev/net/tun"
#        "--cap-add=NET_ADMIN"
#      ];
#  };
}
