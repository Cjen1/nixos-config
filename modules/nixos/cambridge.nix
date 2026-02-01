{pkgs, ...}:{
  environment.systemPackages = [pkgs.krb5];

  programs.ssh.package = pkgs.openssh.override { withKerberos = true; };
  # Kerberos for cambridge
  security.krb5.settings.libdefaults = {
    forwardable = true;
    default_realm = "DC.CL.CAM.AC.UK";
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
