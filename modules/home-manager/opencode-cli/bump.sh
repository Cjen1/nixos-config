#!/usr/bin/env bash
set -euo pipefail

package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$package_dir" rev-parse --show-toplevel)"
version="${1:-latest}"
max_jobs=$(( $(nproc) / 2 ))
if [ "$max_jobs" -lt 1 ]; then
  max_jobs=1
fi

cd "$package_dir"

nix shell nixpkgs#nodejs_22 -c npm install --package-lock-only --ignore-scripts --save-exact "opencode-ai@${version}"

pinned_version="$(
  nix shell nixpkgs#nodejs_22 -c node -p \
    "require('./package-lock.json').packages['node_modules/opencode-ai'].version"
)"

nix shell nixpkgs#nodejs_22 -c node -e \
  "const fs = require('fs'); const version = '${pinned_version}'; const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8')); pkg.version = version; pkg.dependencies['opencode-ai'] = version; fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');"
nix shell nixpkgs#nodejs_22 -c npm install --package-lock-only --ignore-scripts

sed -i \
  -e "s/version = \"[^\"]*\";/version = \"${pinned_version}\";/" \
  -e "s#npmDepsHash = \"sha256-[^\"]*\";#npmDepsHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";#" \
  default.nix

build_expr="let flake = builtins.getFlake \"git+file://${repo_root}\"; pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux; src = builtins.path { path = \"${package_dir}\"; name = \"opencode-cli-src\"; }; in pkgs.callPackage src {}"

set +e
build_output="$(nix build --max-jobs "$max_jobs" --cores "$max_jobs" --impure --no-link --show-trace --print-build-logs --expr "$build_expr" 2>&1)"
build_status=$?
set -e

if [ "$build_status" -eq 0 ]; then
  echo "Build unexpectedly succeeded with the fake npmDepsHash." >&2
  exit 1
fi

new_hash="$(printf '%s\n' "$build_output" | sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | tail -n 1)"

if [ -z "$new_hash" ]; then
  printf '%s\n' "$build_output" >&2
  echo "Could not extract npmDepsHash from Nix output." >&2
  exit 1
fi

sed -i "s#npmDepsHash = \"sha256-[^\"]*\";#npmDepsHash = \"${new_hash}\";#" default.nix

nix build --max-jobs "$max_jobs" --cores "$max_jobs" --impure --no-link --expr "$build_expr"

echo "Pinned opencode-ai ${pinned_version}"
echo "npmDepsHash = ${new_hash}"
