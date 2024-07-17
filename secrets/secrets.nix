let
  home-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOeHK5WOR8Yyt6bj9cBOmBshsGfulZC0czWufimgALzc cjen1@jasper";
  jasper-host-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINTl9JEmQ8d6Zwi5FYFZfTCapUyHtLhSFcVhM2pGwXys root@jasper";
in {
  "protonvpn.age".publicKeys = [ home-key jasper-host-key ];
  "protonvpn-netherlands.wireguard.age".publicKeys = [ home-key jasper-host-key ];
}
