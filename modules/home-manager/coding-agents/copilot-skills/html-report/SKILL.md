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

Serve only the report directory, bound to loopback, e.g.:
`python3 -m http.server <port> --bind 127.0.0.1 --directory /path/to/reports`.
Keep the server running as a persistent background process while the report is needed.

On a remote fleet node with `msft-report-forward`, run
`msft-report-forward <port>` as another persistent background process. It prints
`http://localhost:<allocated-host-port>`; append the report's relative path and
give that plain URL to the user. Verify the page through the allocated host
port if possible, as well as the remote server. Multiple nodes and helpers can
run concurrently without choosing host ports. A disconnected helper exits
nonzero; rerun it and give the user its new URL. If the relay is unavailable,
report the failure rather than making the report public.

On local WSL, open `explorer.exe "http://localhost:<port>/relative_path_to_file.html"`.
Elsewhere without a relay, provide the server URL and explain any required
forwarding. Stop the forwarding helper and HTTP server when no longer needed.
Server logs show requests, not proof that the user opened or read the page.
