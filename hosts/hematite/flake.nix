{
  description = "Hematite NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    arion.url = "github:hercules-ci/arion";
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.hematite = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
        };
        modules = [
          inputs.home-manager.nixosModules.home-manager
          inputs.arion.nixosModules.arion
          ./default.nix
        ];
      };
    };
}
