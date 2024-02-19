{pkgs, ...}:
let
  python = pkgs.python3.withPackages(ps: [ps.dpkt]);
in
pkgs.writeShellScriptBin "pcap_bw_dir" ''
  ${python}/bin/python ${./pcap_bw.py} "$@"
''
