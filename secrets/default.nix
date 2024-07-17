{inputs, ...}: {
  imports = [
    inputs.agenix.nixosModules.default
  ];

  age.secrets."protonvpn-netherlands.wireguard".file = ./protonvpn-netherlands.wireguard.age;
}
