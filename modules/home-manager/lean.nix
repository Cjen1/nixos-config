# Pins one nixpkgs revision for Lean work, so every project shares one
# store copy of mathlib. Projects use `inputs.nixpkgs.url = "lean-nixpkgs";`
# and take Lean and mathlib from `leanPackages`.
# Bump with `nix flake update lean-nixpkgs`, then run
# `scripts/check-lean-nixpkgs-cache.sh` to confirm Hydra has built mathlib.
{ leanNixpkgs, ... }:
{
  nix.registry.lean-nixpkgs.to = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    inherit (leanNixpkgs) rev;
  };
}
