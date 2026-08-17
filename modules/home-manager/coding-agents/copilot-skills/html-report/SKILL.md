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

Host a small web server over localhost serving the file, eg: `cd /path/to/parent/folder/ && python3 -m http.server <port>`
Then if on WSL you can open this via `explorer.exe "http://localhost:<port>/relative_path_to_file.html"`, otherwise just output a plain URL (as formatting isn't generally preserved for clickable links).
Finally to validate that the webpage was opened successfully, check the server logs.
