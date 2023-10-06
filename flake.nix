{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = {nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations = {
      graphite = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs;};
        modules = [
          ./nixos-systems/graphite
        ];
      };
      mercury = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs;};
        modules = [
          ./nixos-systems/mercury
        ];
      };
    };

    homeConfigurations = {
      "cjen1@graphite" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs;};
        modules = [
          ./home-manager/graphite
        ];
      };
      "cjen1@binky" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs;};
        modules = [
          ./home-manager/binky
        ];
      };
    };
  };
}
