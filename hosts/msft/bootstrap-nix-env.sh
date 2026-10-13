#!/usr/bin/env bash
set -Eeuo pipefail

repo_url="$1"
repo_dir="$2"
operation="${3:-bootstrap}"
stage="checking remote prerequisites"
report_error() {
  local status=$?
  echo "error: $stage failed (exit $status)" >&2
  exit "$status"
}
trap report_error ERR

fail() {
  echo "error: $*" >&2
  exit 1
}

[[ "$operation" == bootstrap || "$operation" == update ]] || fail "unknown operation: $operation"
[[ "$(id -u)" == 0 ]] || fail "remote Home Manager requires root; configure the SSH alias to log in as root"
tools=(git)
if [[ "$operation" == bootstrap ]]; then
  tools+=(curl)
fi
for tool in "${tools[@]}"; do
  command -v "$tool" >/dev/null || fail "install $tool in the devcontainer before bootstrapping"
done

load_nix() {
  if ! command -v nix >/dev/null 2>&1; then
    if [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    elif [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]]; then
      . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
    fi
  fi
}

stage="loading Nix"
load_nix
if ! command -v nix >/dev/null 2>&1; then
  [[ "$operation" == bootstrap ]] || fail "Nix is unavailable; run msft-fleet-bootstrap first"
  stage="installing Nix"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    sh -s -- install linux --init none --no-confirm
  load_nix
fi
command -v nix >/dev/null || fail "Nix is still unavailable after installation; inspect /nix before rerunning"

stage="synchronizing $repo_dir with origin/main"
if [[ -e "$repo_dir" || -L "$repo_dir" ]]; then
  [[ -d "$repo_dir/.git" ]] || fail "$repo_dir exists but is not a Git checkout"
  origin="$(git -C "$repo_dir" remote get-url origin)"
  [[ "$origin" == "$repo_url" ]] ||
    fail "$repo_dir has an unexpected origin; expected $repo_url"
  changes="$(git -C "$repo_dir" status --porcelain --untracked-files=all)"
  [[ -z "$changes" ]] ||
    fail "refusing to update dirty checkout at $repo_dir"
  branch="$(git -C "$repo_dir" symbolic-ref --short HEAD)"
  [[ "$branch" == main ]] ||
    fail "$repo_dir must be on branch main"
  git -C "$repo_dir" fetch origin refs/heads/main:refs/remotes/origin/main
  git -C "$repo_dir" merge-base --is-ancestor HEAD origin/main ||
    fail "$repo_dir has commits that are not on origin/main"
  git -C "$repo_dir" merge --ff-only origin/main
else
  [[ "$operation" == bootstrap ]] || fail "$repo_dir is missing; run msft-fleet-bootstrap first"
  git clone --branch main --single-branch "$repo_url" "$repo_dir"
fi

stage="building remote Home Manager"
cd "$repo_dir"
activation="$(
  nix --extra-experimental-features 'nix-command flakes' build \
    ./hosts/msft#homeConfigurations.remote.activationPackage \
    --no-link --no-write-lock-file --print-out-paths \
    --max-jobs "$(( ($(nproc) + 1) >> 1 ))" \
    --cores "$(( ($(nproc) + 1) >> 1 ))"
)"
[[ -n "$activation" && "$activation" != *$'\n'* && -x "$activation/activate" ]] ||
  fail "Nix did not return one executable activation package"
stage="activating remote Home Manager"
"$activation/activate"
