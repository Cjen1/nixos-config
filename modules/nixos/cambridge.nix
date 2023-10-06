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
  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    clientConf = "ServerName cups-serv.cl.cam.ac.uk";
  };

}
