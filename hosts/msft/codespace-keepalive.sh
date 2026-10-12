#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: codespace-keepalive <fleet-alias>\n' >&2
  exit 64
fi
alias="$1"
if ! codespace="$(
  jq -er --arg alias "$alias" \
    '.[$alias].codespace // error("no Codespace registered for alias: " + $alias)' \
    "${MSFT_FLEET_FILE:?Missing MSFT_FLEET_FILE}"
)"; then
  printf 'error: cannot keep Codespace %s alive; check the fleet registry\n' "$alias" >&2
  exit 1
fi

export GH_PROMPT_DISABLED=1
export GH_NO_UPDATE_NOTIFIER=1
printf 'Keeping %s (%s) running through GitHub CLI activity heartbeats\n' "$alias" "$codespace"
if gh codespace ssh --codespace "$codespace" -- \
  -T \
  -i "$HOME/.ssh/codespaces.auto" \
  -o BatchMode=yes \
  -o ConnectTimeout=30 \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  'exec sleep infinity'
then
  printf 'error: keepalive connection for %s (%s) ended unexpectedly\n' "$alias" "$codespace" >&2
  exit 1
else
  status=$?
  printf 'error: keepalive connection for %s (%s) failed with status %s\n' \
    "$alias" "$codespace" "$status" >&2
  exit "$status"
fi
