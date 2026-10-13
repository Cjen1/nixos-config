#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == --help ]]; then
  echo "Usage: msft-fleet-update [fleet-alias ...]"
  echo "Without aliases, updates every registered host."
  exit 0
fi

registry="${MSFT_FLEET_FILE:?MSFT_FLEET_FILE must point to the fleet registry}"
aliases=("$@")
if [[ $# -eq 0 ]]; then
  names="$(jq -er 'if type == "object" then keys[] else error("expected a fleet object") end' "$registry")" || {
    # jq -e also returns 4 for a valid empty registry.
    if ! jq -e '. == {}' "$registry" >/dev/null; then
      echo "error: cannot read fleet registry $registry" >&2
      exit 1
    fi
    echo "No hosts registered."
    exit 0
  }
  mapfile -t aliases <<< "$names"
fi

for alias in "${aliases[@]}"; do
  if [[ ! "$alias" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] ||
    ! jq -e --arg alias "$alias" '.[$alias] |
      if .kind == "codespace" then (.data.name | type == "string" and length > 0)
      elif .kind == "ssh" then (.data.destination | type == "string" and length > 0)
      else false end' "$registry" >/dev/null; then
    echo "error: unknown or invalid fleet alias '$alias'; check the fleet registry" >&2
    exit 1
  fi
done

export GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1
failed=()
for alias in "${aliases[@]}"; do
  echo "Updating $alias from origin/main"
  if ssh \
    -T \
    -o BatchMode=yes \
    -o ConnectionAttempts=1 \
    -o ConnectTimeout=30 \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    "$alias" 'bash -s -- https://github.com/Cjen1/nixos-config.git /root/nixos-config update' \
    < "${MSFT_BOOTSTRAP_SCRIPT:?MSFT_BOOTSTRAP_SCRIPT must point to the remote deployment script}"; then
    echo "Updated $alias"
  else
    status=$?
    echo "error: update failed for $alias (exit $status); continuing with remaining hosts" >&2
    failed+=("$alias")
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "error: failed to update: ${failed[*]}" >&2
  exit 1
fi
