{
  description = "Shale NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixpkgs-zotify.url = "github:bwkam/nixpkgs/init-zotify";
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.shale = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          zotify-dev = inputs.nixpkgs-zotify.legacyPackages.${system}.zotify;
        };
        modules = [
          inputs.home-manager.nixosModules.home-manager
          inputs.nixos-wsl.nixosModules.wsl
          ./default.nix
        ];
      };
    };
}
