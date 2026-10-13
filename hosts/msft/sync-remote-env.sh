#!/usr/bin/env bash
set -euo pipefail

if [[ ! -e "$HOME/.env" && ! -L "$HOME/.env" ]]; then
  exit 0
fi

if [[ ! -f "$HOME/.env" || ! -r "$HOME/.env" ]]; then
  echo "error: cannot read local environment file $HOME/.env" >&2
  exit 1
fi

alias="$1"
echo "Copying ~/.env to $alias"
if ssh \
  -T \
  -o BatchMode=yes \
  -o ConnectionAttempts=1 \
  -o ConnectTimeout=30 \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  "$alias" 'bash -c '"'"'
    set -euo pipefail
    umask 077
    temporary=$(mktemp /root/.env.XXXXXX)
    trap "rm -f -- \"\$temporary\"" EXIT
    cat > "$temporary"
    mv -fT -- "$temporary" /root/.env
  '"'"'' < "$HOME/.env"; then
  echo "Copied ~/.env to $alias"
else
  status=$?
  echo "error: environment copy failed for $alias (exit $status)" >&2
  exit "$status"
fi
