# Keep the mathlib revision below aligned when updating lean-nixpkgs.
{
  leanNixpkgs,
  lib,
  pkgs,
  ...
}:
let
  leanPackages = leanNixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.leanPackages;
  inherit (leanPackages) lean4 mathlib;
  dependencies = [ mathlib ] ++ mathlib.allLeanDeps;
  packages = map (dependency: {
    name = dependency.lakePackageName;
    dir = "${dependency}";
  }) dependencies;
  overrides = pkgs.writeText "lean-package-overrides.json" (
    builtins.toJSON {
      schemaVersion = "1.2.0";
      packages = map (
        package:
        package
        // {
          type = "path";
          inherited = false;
        }
      ) packages;
    }
  );
  sharedConfig = pkgs.writeText "lean-shared.json" (
    builtins.toJSON {
      toolchain = "leanprover/lean4:v${lean4.version}";
      mathlibRevision = "56a005855ea17e0b0958f73ec801ae140b0a1679";
      inherit packages;
    }
  );
  shared = pkgs.linkFarm "lean-shared-packages" (
    map (package: {
      name = "packages/${package.name}";
      path = package.dir;
    }) packages
    ++ [
      {
        name = "config.json";
        path = sharedConfig;
      }
      {
        name = "package-overrides.json";
        path = overrides;
      }
    ]
  );
  share = pkgs.writeShellApplication {
    name = "lean-share";
    runtimeInputs = [ pkgs.git ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./lean-share.py} \
        --shared ${shared} "$@"
    '';
  };
in
{
  assertions = [
    {
      assertion = lean4.version == "4.35.0" && mathlib.version == "4.35.0";
      message = "Update the shared mathlib Git revision and compatibility checks when changing Lean versions.";
    }
  ];
  home.packages = [
    (lib.hiPrio lean4)
    share
  ];
  home.file.".local/share/lean-shared".source = shared;

  nix.registry.lean-nixpkgs.to = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    inherit (leanNixpkgs) rev;
  };
}
