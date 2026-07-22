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
    custom-tooling.url = "git+https://forgejo.ts.jentek.dev/cjen1/custom-tooling";
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
      "cjen1-msft@msft" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {
          inherit inputs;
          t3CodePackage =
            let
              unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
              version = "0.0.29-nightly.20260722.875";
              pnpm = unstable.pnpm_11.override {
                version = "11.10.0";
                hash = "sha512-C3+LmAYAMZBMAX46QesYehbUDuuCm5XE+MsDaBdh/Eq1PdIZEVubRH9NzhoFohR2RGHn03AzkqnzL5URzoyGyA==";
              };
              nightly = unstable.t3code.overrideAttrs (finalAttrs: previousAttrs: {
                inherit version;
                src = unstable.fetchFromGitHub {
                  owner = "pingdotgg";
                  repo = "t3code";
                  tag = "v${version}";
                  hash = "sha256-MRcUURTvXwGpB/5xiLDBX3Iz47WT2mJPWCJhrnpOYLk=";
                };
                pnpmDeps = unstable.fetchPnpmDeps {
                  inherit (finalAttrs)
                    pname
                    version
                    src
                    pnpmWorkspaces
                    ;
                  inherit pnpm;
                  fetcherVersion = 4;
                  hash = "sha256-bfZDQjVdT0neQYxmNB8t+XU8mbjVsAtaTi2Vms5pzxw=";
                };
                nativeBuildInputs = map (
                  package:
                  if package == unstable.pnpm_10 then pnpm else package
                ) previousAttrs.nativeBuildInputs;
                preBuild = ''
                  export pnpm_config_verify_deps_before_run=
                ''
                + previousAttrs.preBuild;
              });
            in
            unstable.symlinkJoin {
              name = "t3code-with-secret-service";
              paths = [ nightly ];
              nativeBuildInputs = [ unstable.makeWrapper ];
              postBuild = ''
                wrapProgram "$out/bin/t3code-desktop" \
                  --add-flags "--password-store=gnome-libsecret"
              '';
            };
        };
        modules = [
          ./home-manager/msft
        ];
      };
    };
  };
}
