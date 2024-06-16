{pkgs, ...}:
let
    python = pkgs.python3.withPackages (ps: [ps.flask ps.requests]);
#    webapp = pkgs.stdenv.mkDerivation {
#      name = "wedding-rsvp";
#      src = ./.;
#      buildInputs = [python];
#
#      installPhase = ''
#        mkdir -p $out/bin
#        cp ${./webapp.py} $out/bin/webapp.py
#        chmod +x $out/bin/webapp.py
#      '';
#    };
in{
  systemd.services.wedding_rsvp = {
    description = "Wedding RSVP form";
    after = ["network.target"];

    serviceConfig = {
      ExecStart = "${python}/bin/python ${./webapp.py} -- 10001 /data/wedding_rsvp/log.txt";
      Restart = "on-failure";
      User = "cjen1";
    };

    wantedBy = ["multi-user.target"];
  };
}
