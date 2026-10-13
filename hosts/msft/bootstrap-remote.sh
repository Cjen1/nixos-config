#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bootstrap-codespace-nix-env <fleet-alias>" >&2
  exit 64
fi
alias="$1"
if [[ ! "$alias" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] ||
  ! jq -e --arg alias "$alias" '.[$alias] |
    if .kind == "codespace" then (.data.name | type == "string" and length > 0)
    elif .kind == "ssh" then (.data.destination | type == "string" and length > 0)
    else false end' \
    "${MSFT_FLEET_FILE:?MSFT_FLEET_FILE must point to the fleet registry}" >/dev/null; then
  echo "error: unknown fleet alias '$alias'; check the fleet registry" >&2
  exit 1
fi

export GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1
echo "Bootstrapping $alias from origin/main"
if ssh \
  -T \
  -o BatchMode=yes \
  -o ConnectionAttempts=1 \
  -o ConnectTimeout=30 \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  "$alias" 'bash -s -- https://github.com/Cjen1/nixos-config.git /root/nixos-config' \
  < "${MSFT_BOOTSTRAP_SCRIPT:?MSFT_BOOTSTRAP_SCRIPT must point to the remote bootstrap script}"; then
  echo "Bootstrapped $alias"
else
  status=$?
  echo "error: bootstrap failed for $alias (exit $status); fix the reported error and rerun" >&2
  exit "$status"
fi
