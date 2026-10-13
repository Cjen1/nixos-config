#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: msft-fleet-keepalive <fleet-alias>\n' >&2
  exit 64
fi
alias="$1"
if ! entry="$(
  jq -er --arg alias "$alias" \
    '.[$alias] |
      if .kind == "codespace" then [.kind, .data.name]
      elif .kind == "ssh" then [.kind, .data.destination]
      else error("no host registered for alias: " + $alias) end |
      if (.[1] | type == "string" and length > 0) then @tsv
      else error("missing destination for alias: " + $alias) end' \
    "${MSFT_FLEET_FILE:?Missing MSFT_FLEET_FILE}"
)"; then
  printf 'error: cannot keep host %s connected; check the fleet registry\n' "$alias" >&2
  exit 1
fi
IFS=$'\t' read -r kind target <<< "$entry"
if [[ "$kind" == codespace ]]; then
  transport=(gh codespace ssh --codespace "$target" -- -i "$HOME/.ssh/codespaces.auto")
else
  transport=(ssh)
fi
arguments=(
  -T
  -o BatchMode=yes
  -o ConnectTimeout=30
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=3
  -o ExitOnForwardFailure=yes
  -R 127.0.0.1:5588:127.0.0.1:2222
)
if [[ "$kind" == ssh ]]; then
  arguments+=("$alias")
fi
# shellcheck disable=SC2016
remote_command='bash -c '"'"'
  set -euo pipefail
  umask 077
  target="$HOME/.config/msft-report-relay"
  mkdir -p "$target"
  chmod 700 "$target"
  temporary=$(mktemp -d "$target/.install.XXXXXX")
  trap "rm -f \"\$temporary/identity\" \"\$temporary/known_hosts\" \"\$temporary/config\"; rmdir \"\$temporary\"" EXIT
  tar -xf - -C "$temporary"
  chmod 600 "$temporary/identity" "$temporary/known_hosts" "$temporary/config"
  mv "$temporary/identity" "$temporary/known_hosts" "$temporary/config" "$target/"
  rmdir "$temporary"
  trap - EXIT
  exec cat >/dev/null
'"'"''

export GH_PROMPT_DISABLED=1
export GH_NO_UPDATE_NOTIFIER=1
printf 'Keeping %s (%s) connected with a report return tunnel\n' "$alias" "$target"
if msft-report-relay-session "${transport[@]}" "${arguments[@]}" "$remote_command"
then
  printf 'error: keepalive connection for %s (%s) ended unexpectedly\n' "$alias" "$target" >&2
  exit 1
else
  status=$?
  printf 'error: keepalive connection for %s (%s) failed with status %s\n' \
    "$alias" "$target" "$status" >&2
  exit "$status"
fi
