{pkgs, ...}: let
  username = "cjj39+graphite_vpn@cam.ac.uk";
in {
  environment.systemPackages = [pkgs.strongswan];
  services.strongswan = {
    enable = true;
    # Passwords set up as per https://help.uis.cam.ac.uk/service/network-services/remote-access/uis-vpn/ubuntu1604#password-file
    secrets = ["/var/lib/ipsec.secrets"];
    connections.CAM = {
      left = "%any";
      leftid = username;
      leftauth = "eap";
      leftsourceip = "%config";
      leftfirewall = "yes";
      right = "vpn.uis.cam.ac.uk";
      rightid = "\"CN=vpn.uis.cam.ac.uk\"";
      # from https://help.uis.cam.ac.uk/service/network-services/remote-access/uis-vpn/ubuntu1604
      rightcert = toString ./cambridge-vpn-2022.crt;
      rightsubnet = "0.0.0.0/0";
      auto = "add";
    };
  };
}
