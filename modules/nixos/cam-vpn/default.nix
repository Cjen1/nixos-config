{pkgs, ...}: let
  username_cam = "cjj39+graphite_vpn@cam.ac.uk";
  username_cl = "cjj39-graphite";
in {
  environment.systemPackages = [pkgs.strongswan];
  services.strongswan = {
    enable = true;
    # Passwords set up as per https://help.uis.cam.ac.uk/service/network-services/remote-access/uis-vpn/ubuntu1604#password-file
    secrets = ["/var/lib/ipsec.secrets"];
    connections.CAM = {
      left = "%any";
      leftid = username_cam;
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

    # Setup instructions: https://www.cst.cam.ac.uk/local/sys/vpn2/linux
    # Password from https://vpnpassword.cl.cam.ac.uk/
    connections.CL = {
      reauth = "no";
      left = "%any";
      leftid = username_cl;
      leftauth = "eap";
      leftsourceip = "%config4,%config6";
      leftfirewall = "yes";
      right = "vpn2.cl.cam.ac.uk";
      rightid = "%any";
      rightsendcert = "never";
      rightsubnet = "128.232.0.0/16,129.169.0.0/16,131.111.0.0/16,192.18.195.0/24,193.60.80.0/20,193.63.252.0/23,172.16.0.0/13,172.24.0.0/14,172.28.0.0/15,172.30.0.0/16,10.128.0.0/9,10.64.0.0/10,2001:630:210::/44,2a05:b400::/32";
      auto = "add";
    };
    ca.CL = {
      auto = "add";
      cacert = "${./cambridge-cl-vpn-2023.pem}";
    };
  };
}
