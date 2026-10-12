#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git -C "$1" rev-parse --show-toplevel)"
tools_expr="let flake = builtins.getFlake \"git+file://${repo_root}?dir=hosts/mercury\"; pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux; in [ pkgs.nodejs_22 pkgs.prefetch-npm-deps ]"

exec nix shell --impure --expr "$tools_expr" -c \
  node "$repo_root/scripts/bump-npm-package.mjs" "$repo_root" "$@"
