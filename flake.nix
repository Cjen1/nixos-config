{
  description = "nixos config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    arion.url = "github:hercules-ci/arion";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixpkgs-zotify.url = "github:bwkam/nixpkgs/init-zotify";
    agenix.url = "github:ryantm/agenix";
    ps-todos.url = "github:Cjen1/ps-todos/nix-flake-systemd-service";
  };

  outputs = {nixpkgs, home-manager, ... }@inputs: 
  {
    nixosConfigurations = {
      graphite = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
        };
        modules = [
          ./nixos-systems/graphite
        ];
      };
      mercury = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; 
                        unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
                      };
        modules = [
          ./nixos-systems/mercury
        ];
      };
      hematite = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; 
                        unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
                      };
        modules = [
          ./nixos-systems/hematite
        ];
      };
      jasper = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; 
                        unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
                      };
        modules = [
          ./nixos-systems/jasper
        ];
      };
      shale = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
          zotify-dev = inputs.nixpkgs-zotify.legacyPackages.x86_64-linux.zotify;
        };
        modules = [
          ./nixos-systems/shale
        ];
      };
    };

    homeConfigurations = {
      "cjen1@graphite" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit inputs;
          unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
          wayland_display_config = { };
        };
        modules = [
          ./home-manager/graphite
        ];
      };
      "cjj39@binky" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit inputs;
          unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
        };
        modules = [
          ./home-manager/binky
        ];
      };
      "cjj39@quoth" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit inputs;
          unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
        };
        modules = [
          ./home-manager/quoth
        ];
      };
      "cjen1@shale" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit inputs;
          unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
        };
        modules = [
          ./home-manager/shale
        ];
      };
      "cjen1@hematite" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit inputs;
          unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
          wayland_display_config = { };
        };
        modules = [
          ./home-manager/hematite
        ];
      };
    };
  };
}
