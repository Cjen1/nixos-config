{
  description = "MSFT Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Shared nixpkgs revision for Lean projects; see modules/home-manager/lean.nix.
    lean-nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      lean-nixpkgs,
      ...
    }:
    let
      homeConfiguration =
        extraSpecialArgs:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = extraSpecialArgs // {
            leanNixpkgs = lean-nixpkgs;
          };
          modules = [
            ./home.nix
          ];
        };
    in
    {
      homeConfigurations = {
        cjen1-msft = homeConfiguration {
          isRemote = false;
        };
        remote = homeConfiguration {
          isRemote = true;
        };
      };
    };
}
