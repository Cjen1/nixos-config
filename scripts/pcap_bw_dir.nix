{pkgs, ...}:
let
  python = pkgs.python3.withPackages(ps: [ps.dpkt]);
in
pkgs.writeShellScriptBin "pcap_bw_dir" ''
  for f in ''$(find ''$1 | grep pcap); do
    ${python}/bin/python ${./pcap_bw.py} --tcp -w ''$2 "''$f" > "''${f}.csv" &
  done
  wait
''
