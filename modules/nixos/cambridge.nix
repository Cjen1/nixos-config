{pkgs, ...}:{
  environment.systemPackages = [pkgs.krb5];
  # Kerberos for cambridge
  krb5 = {
    config = ''
      [libdefaults]
      forwardable = true
      default_realm = DC.CL.CAM.AC.UK
      '';
  };

  #services = {
  #  printing.enable = true;
  #  avahi.enable = true;
  #  avahi.nssmdns = true;
  #  avahi.openFirewall = true;
  #};

  services.printing = {
    enable = true;
#    browsing = true;
#    defaultShared = true;
    clientConf = "ServerName cups-serv.cl.cam.ac.uk";
  };
}
