#!/usr/bin/env bash
set -euo pipefail

state="${MSFT_REPORT_RELAY_STATE:-$HOME/.local/state/msft-report-relay}"
umask 077
mkdir -p "$state/sessions"
chmod 700 "$state"
exec 9>"$state/setup.lock"
flock 9
temporary="$(mktemp -d "$state/.setup.XXXXXX")"
trap 'rm -f "$temporary/key" "$temporary/key.pub"; rmdir "$temporary"' EXIT
if [[ ! -e "$state/host-key" ]]; then
  ssh-keygen -q -t ed25519 -N '' -f "$temporary/key"
  mv "$temporary/key" "$state/host-key"
  rm "$temporary/key.pub"
fi
chmod 600 "$state/host-key"
ssh-keygen -y -f "$state/host-key" > "$temporary/key.pub"
mv "$temporary/key.pub" "$state/host-key.pub"
