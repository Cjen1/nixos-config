{pkgs, ...}: 
let 
  pcap_bw = import ../../scripts/pcap_bw.nix {inherit pkgs;};
  pcap_bw_dir = import ../../scripts/pcap_bw_dir.nix {inherit pkgs;};
  gs-compress = import ../../scripts/ghost-script-compress.nix {inherit pkgs;};
in{
  home.packages = [
    pcap_bw
    pcap_bw_dir
    gs-compress
  ];
}
