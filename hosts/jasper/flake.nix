{
  description = "Jasper NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Update Navidrome independently of the host's other package pins.
    nixpkgs-navidrome.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    arion.url = "github:hercules-ci/arion";
    custom-tooling.url = "git+https://forgejo.ts.jentek.dev/cjen1/custom-tooling";
    ps-todos.url = "github:Cjen1/ps-todos/nix-flake-systemd-service";
    web-nightjar = {
      url = "git+ssh://git@github.com/Cjen1/web-nightjar?rev=66732926204af7ee939f657b79494b55a582b102";
      flake = false;
    };
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.jasper = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
        };
        modules = [
          inputs.home-manager.nixosModules.home-manager
          inputs.agenix.nixosModules.default
          inputs.arion.nixosModules.arion
          inputs.custom-tooling.nixosModules.default
          inputs.ps-todos.nixosModules.default
          ./default.nix
        ];
      };
    };
}
