#!/usr/bin/env bash
# Checks that the `lean-nixpkgs` revision pinned by a host has mathlib in
# cache.nixos.org, so projects substitute it instead of building it.
# Usage: scripts/check-lean-nixpkgs-cache.sh [host-dir]   (default: hosts/msft)
set -euo pipefail

host_dir="${1:-hosts/msft}"
rev="$(jq -r '.nodes["lean-nixpkgs"].locked.rev' "$host_dir/flake.lock")"
ref="github:NixOS/nixpkgs/$rev"

lean="$(nix eval --raw "$ref#leanPackages.lean4.version")"
mathlib="$(nix eval --raw "$ref#leanPackages.mathlib.version")"
archive="$(nix eval --raw "$ref#leanPackages.mathlib.mathlib__archive.outPath")"

echo "lean-nixpkgs $rev: lean $lean, mathlib $mathlib"
if nix path-info --store https://cache.nixos.org "$archive" >/dev/null 2>&1; then
  echo "ok: $archive is cached"
else
  echo "error: $archive is not in cache.nixos.org; pick another revision" >&2
  exit 1
fi
