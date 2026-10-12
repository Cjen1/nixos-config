#!/usr/bin/env bash
set -euo pipefail

config_dir="$HOME/.ssh"
config_file="$config_dir/config"
include='Include ~/.ssh/msft-fleet.conf'

if [[ -f "$config_file" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$include" ]]; then
      exit 0
    fi
    if [[ "${line,,}" =~ ^[[:space:]]*(host|match)[[:space:]] ]]; then
      break
    fi
  done < "$config_file"
fi
if [[ -L "$config_file" ]]; then
  printf 'error: %s is a symlink; add "%s" through its configuration manager\n' \
    "$config_file" "$include" >&2
  exit 1
fi
if [[ -e "$config_file" && ! -f "$config_file" ]]; then
  printf 'error: %s is not a regular file\n' "$config_file" >&2
  exit 1
fi

mkdir -p "$config_dir"
chmod 700 "$config_dir"
temporary="$(mktemp "$config_dir/.msft-fleet-config.XXXXXX")"
trap 'rm -f "$temporary"' EXIT
{
  printf '%s\n\n' "$include"
  if [[ -f "$config_file" ]]; then
    cat "$config_file"
  fi
} > "$temporary"
chmod 600 "$temporary"
mv "$temporary" "$config_file"
