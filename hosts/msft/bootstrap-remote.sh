#!/usr/bin/env bash
set -euo pipefail

host="${MSFT_REMOTE_HOST:-20.91.249.202}"
port="${MSFT_REMOTE_PORT:-22}"
identity="${MSFT_REMOTE_IDENTITY:-$HOME/.ssh/azure}"
repo_url="${MSFT_REPO_URL:-https://github.com/Cjen1/nixos-config.git}"
repo_dir="/root/nixos-config"

ssh_args=(
  -i "$identity"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -p "$port"
  "root@$host"
)

ssh "${ssh_args[@]}" bash -s -- "$repo_url" "$repo_dir" <<'REMOTE'
set -euo pipefail

repo_url="$1"
repo_dir="$2"

if ! command -v nix >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    sh -s -- install linux --init none --no-confirm
fi

if [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
fi

if [[ -d "$repo_dir/.git" ]]; then
  if [[ -n "$(git -C "$repo_dir" status --porcelain --untracked-files=all)" ]]; then
    echo "error: refusing to update dirty checkout at $repo_dir" >&2
    exit 1
  fi
  git -C "$repo_dir" checkout main
  git -C "$repo_dir" fetch origin main
  if ! git -C "$repo_dir" merge-base --is-ancestor HEAD origin/main; then
    echo "error: $repo_dir has commits that are not on origin/main" >&2
    exit 1
  fi
  git -C "$repo_dir" merge --ff-only origin/main
else
  git clone "$repo_url" "$repo_dir"
fi

cd "$repo_dir"
activation="$(
  nix build \
    ./hosts/msft#homeConfigurations.remote.activationPackage \
    --no-link \
    --no-write-lock-file \
    --print-out-paths
)"
"$activation/activate"

/root/.nix-profile/bin/home-manager generations
REMOTE
