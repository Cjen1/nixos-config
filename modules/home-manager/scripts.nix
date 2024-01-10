{pkgs, ...}: 
let 
  pcap_bw = import ../../scripts/pcap_bw.nix {inherit pkgs;};
in{
  home.packages = [
    pcap_bw
  ];
}
