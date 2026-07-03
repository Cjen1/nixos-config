{inputs, ...}: {
  imports = [
    inputs.agenix.nixosModules.default
  ];

  age.secrets."protonvpn-netherlands.wireguard".file = ./protonvpn-netherlands.wireguard.age;
  age.secrets."audiomuse-jellyfin-token".file = ./audiomuse-jellyfin-token.age;
  age.secrets."dex-password-hash" = {
    file = ./dex-password-hash.age;
    group = "keys";
    mode = "0440";
  };
  age.secrets."dex-tailscale-client-secret".file = ./dex-tailscale-client-secret.age;
}
