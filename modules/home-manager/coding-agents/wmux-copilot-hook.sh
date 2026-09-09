#!/usr/bin/env bash
set -euo pipefail

event="${1:?Expected a Copilot hook event}"
payload="$(cat)"
if [ "${#payload}" -gt 49152 ]; then
    printf 'wmux: Copilot hook payload exceeds 49152 characters\n' >&2
    exit 1
fi
encoded="$(printf '%s' "$payload" | base64 | tr -d '\r\n')"
if [ "${#encoded}" -gt 81920 ]; then
    printf 'wmux: encoded Copilot hook payload exceeds 81920 bytes\n' >&2
    exit 1
fi
tty_path="${WMUX_TTY_PATH:-/dev/tty}"

if [ -n "${TMUX:-}" ]; then
    tmux set-option -p -t "${TMUX_PANE:?Missing tmux pane ID}" allow-passthrough on
    printf '\033Ptmux;\033\033]777;wmux;copilot;%s;%s\007\033\134' \
        "$event" "$encoded" > "$tty_path"
else
    printf '\033]777;wmux;copilot;%s;%s\007' \
        "$event" "$encoded" > "$tty_path"
fi
