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

repair_lockfile_integrities() {
  nix shell nixpkgs#nodejs_22 -c node <<'NODE'
const { execFileSync } = require("node:child_process");
const fs = require("node:fs");

const lock = JSON.parse(fs.readFileSync("package-lock.json", "utf8"));
for (const [path, entry] of Object.entries(lock.packages)) {
  if (!path || entry.link || entry.integrity || !entry.resolved) {
    continue;
  }

  const name = path.slice(path.lastIndexOf("node_modules/") + "node_modules/".length);
  entry.integrity = execFileSync(
    "npm",
    ["view", `${name}@${entry.version}`, "dist.integrity"],
    { encoding: "utf8" },
  ).trim();
}
fs.writeFileSync("package-lock.json", `${JSON.stringify(lock, null, 2)}\n`);
NODE
}

nix shell nixpkgs#nodejs_22 -c npm install --package-lock-only --ignore-scripts --save-exact "@earendil-works/pi-coding-agent@${version}"

pinned_version="$(
  nix shell nixpkgs#nodejs_22 -c node -p \
    "require('./package-lock.json').packages['node_modules/@earendil-works/pi-coding-agent'].version"
)"

nix shell nixpkgs#nodejs_22 -c node -e \
  "const fs = require('fs'); const version = '${pinned_version}'; const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8')); pkg.version = version; pkg.dependencies['@earendil-works/pi-coding-agent'] = version; fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');"
nix shell nixpkgs#nodejs_22 -c npm install --package-lock-only --ignore-scripts
repair_lockfile_integrities

sed -i \
  -e "s/version = \"[^\"]*\";/version = \"${pinned_version}\";/" \
  -e "s#npmDepsHash = \"sha256-[^\"]*\";#npmDepsHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";#" \
  default.nix

build_expr="let flake = builtins.getFlake \"git+file://${repo_root}\"; pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux; src = builtins.path { path = \"${package_dir}\"; name = \"pi-coding-agent-src\"; }; in pkgs.callPackage src {}"

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

echo "Pinned @earendil-works/pi-coding-agent ${pinned_version}"
echo "npmDepsHash = ${new_hash}"
