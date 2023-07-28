{...}:
let
  cam-vpn-cert = "/home/cjen1/cambridge-vpn-2023.crt";
in
{

  strongswan = {
      enable = true;
      secrets = ["/var/lib/ipsec.secrets"];
      connections.CAM = {
        left = "%any";
        leftid = "apj39+xps15vpn@cam.ac.uk";
        leftauth = "eap";
        leftsourceip = "%config";
        leftfirewall = "yes";
        right = "vpn.uis.cam.ac.uk";
        rightid = "%any";
        rightcert = cam-vpn-cert;
        rightsubnet = "0.0.0.0/0";
        auto = "add";
      };
      connections.CL = {
        reauth = "no";
        left = "%any";
        leftid = "apj39-xps15";
        leftauth = "eap";
        leftsourceip = "%config4,%config6";
        leftfirewall = "yes";
        right = "vpn2.cl.cam.ac.uk";
        rightid = "%any";
        rightsendcert = "never";
        rightsubnet = "128.232.0.0/16,129.169.0.0/16,131.111.0.0/16,192.18.195.0/24,193.60.80.0/20,193.63.252.0/23,172.16.0.0/13,172.24.0.0/14,172.28.0.0/15,172.30.0.0/16,10.128.0.0/9,10.64.0.0/10,2001:630:210::/44,2a05:b400::/32";
        auto = "add";
      };
    };
}
