---
name: html-report
description: Use for guidiance on producing an html report
---

Work fractally when writing the report: start from a high-level and then fill in more detail, doing one complete pass at a detail level and then reflecting on the content and revising before continuing.

The steps you should do are the following with a reflect and reconsider step between each.
1. Define a single sentence conceit of the report.
2. Outline the structure using a few words for each section.
3. Start filling in the structure.

Do not just one-shot the entire report.

# Style

- Be consise and direct.
- Use structure to convey meaning
- Use explorable explainations if possible
  - Tables should be sortable and filterable
  - When explaining, consider using an interactive widget or diagram.

## Links

- Linking code
  - use a commit ref to the file on github.
  - use a `vscode://` path
    - On WSL this requires `wslpath -w /path/to/file` to resolve correctly
    - If the target is a dir it will open a new workspace
    - If the target is a file it will open in _a_ workspace.

# Getting the report to the user

## Update the existing page, not its URL

- Keep one canonical HTML file, report directory and browser URL per report.
  Follow-up changes edit that file in place so reloading the existing page shows
  the update. Do not create `report-v2.html`, switch ports or move the directory
  unless the user asks for a separate report or snapshot.
- For generated reports, write a temporary sibling file and atomically replace
  the canonical file after generation succeeds. Do not delete and recreate the
  served directory, or leave the live page truncated during a rewrite.
- Content edits do not require restarting the HTTP server or tunnel. Keep their
  tmux sessions, ports, URL and logs intact. Verify the served page contains the
  actual update; do not infer success from an edited source file alone.

## Keep serving independent of the agent turn

Use dedicated, report-specific **tmux sessions** for both the HTTP server and
`msft-report-forward`, or an equivalent service manager. An ordinary tool-owned
background command can be killed when its tool/session ends; it is not enough.
Keep the processes alive after the final answer, during follow-up edits and
across SSH disconnects. Do not stop them as end-of-turn cleanup.

Before starting anything, inspect existing report state, tmux sessions and
listeners. Reuse a healthy server/tunnel for this report rather than overwriting
its state, truncating its URL log or starting duplicates. If a port belongs to
another report/process, choose a different port for the new report; never kill
the owner to make room.

Serve only the report directory, bound to loopback. For example, run this setup
with Bash after choosing a unique report ID and a free app port. Reuse those
same values for subsequent changes:

```bash
set -euo pipefail
report_id=raft-review
report_dir=/absolute/path/to/reports
report_file=report.html
app_port=8765
state="$HOME/.local/state/html-reports/$report_id"
mkdir -p "$state"

if ! tmux has-session -t "=html-$report_id-http" 2>/dev/null; then
  printf -v command 'exec python3 -u -m http.server %q --bind 127.0.0.1 --directory %q >>%q 2>&1' \
    "$app_port" "$report_dir" "$state/http.log"
  tmux new-session -d -s "html-$report_id-http" -c "$HOME" "$command"
fi

curl --fail --silent --show-error --retry 10 --retry-connrefused --retry-delay 1 \
  "http://127.0.0.1:$app_port/$report_file" >/dev/null

if command -v msft-report-forward >/dev/null &&
   ! tmux has-session -t "=html-$report_id-tunnel" 2>/dev/null; then
  printf -v command 'exec msft-report-forward %q >>%q 2>>%q' \
    "$app_port" "$state/tunnel.url" "$state/tunnel.log"
  tmux new-session -d -s "html-$report_id-tunnel" -c "$HOME" "$command"
fi
```

Stop on a failed HTTP check; do not publish a tunnel to a broken server. On a
remote fleet node the helper runs in its own tmux session as shown above.
The helper prints `http://localhost:<allocated-host-port>` to `tunnel.url`.
Use its latest URL (the last line if a dead helper had to be restarted), append
the report's relative path, and give that plain URL to the user. Record the
canonical file, full URL, app port, tmux session names and state directory in the
session handoff so another turn can reuse them. Verify the page through the
allocated host port if possible, as well as the remote HTTP server. A live tmux
session alone is not proof the page or tunnel works.

The helper retries connection failures every five seconds, reloads relay
credentials, and restores the same URL after a disconnect. Leave it running
during an outage; do not kill/restart it, start duplicates, overwrite its relay
credentials or add another retry loop. Diagnose using `http.log`, `tunnel.log`
and the corresponding tmux pane. Multiple reports can share an existing HTTP
server when the served directory is appropriate; unrelated helpers get their
own automatically allocated host ports.

Tmux survives agent turns and SSH disconnects, not machine/Codespace restarts.
If a process really died, inspect the logs and restore only the missing process
using the same report directory and app port; leave healthy processes alone.
A restarted forwarding helper may allocate a new host port: verify and tell the
user the new full URL instead of claiming the old one still works. If the relay
is unavailable, report the failure rather than making the report public.

On local WSL, open `explorer.exe "http://localhost:<port>/relative_path_to_file.html"`.
Elsewhere without a relay, provide the server URL and explain any required
forwarding. Stop only this report's sessions when the user explicitly asks to
stop serving it; do not kill unrelated sessions or processes.
Server logs show requests, not proof that the user opened or read the page.
