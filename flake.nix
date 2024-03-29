{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/23.11";

    home-manager.url = "github:nix-community/home-manager/release-23.11";
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
      hematite = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs;};
        modules = [
          ./nixos-systems/hematite
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
      "cjen1@shale" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs;};
        modules = [
          ./home-manager/shale
        ];
      };
      "cjen1@hematite" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs;};
        modules = [
          ./home-manager/hematite
        ];
      };
    };
  };
}
