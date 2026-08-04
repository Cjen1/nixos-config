{
  description = "MSFT Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    copilot-in-cc.url = "git+ssh://git@github.com/cjen1-msft/copilot-in-cc.git?ref=main";
  };

  outputs =
    inputs@{ nixpkgs, home-manager, ... }:
    {
      homeConfigurations."cjen1-msft@msft" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          inputs.copilot-in-cc.homeManagerModules.default
          ./home.nix
        ];
      };
    };
}
