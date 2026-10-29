# HTML reports

- When producing an HTML report, link to the files and specific lines it references wherever that helps the reader jump to the source. Use the `vscode://vscode-remote/...` form from the host instructions.
- Also include a link to open the relevant workspace.

# Code style

- Follow YAGNI. Build what the current task needs, not what it might need later, but highlight substantial tradeoffs.
- Keep temporary build artifacts (Lake `.lake`, Cargo `target`, Nix `result`, etc.) under `/tmp` or similar, outside the worktree. Use native output settings; do not symlink them back into the repo. If such artifacts already exist in the worktree, migrate them outside it and update the build configuration accordingly.
- Use variable shadowing to make sequential transformations read imperatively in functional code, e.g. `let foo = foo + 1 in foo`, when it improves clarity.
- Sequence work into minimal verifiable units. Make the smallest independently testable change, verify it, then move to the next. Order commits so a reviewer can follow the evidence.

# General preferences

- A question from the user does not mean that something is wrong and needs to be fixed.
- Do not use the `ask_user` tool. Ask questions inline in your response instead; number options when useful.
- When reporting information to me, be extremely concise and sacrifice grammar for concision.

# Picking the right models for workflows and subagents

Intelligence is how hard a problem you can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy editing.

| model           | cost | intelligence | taste | notes |
| --------------- | ---- | ------------ | ----- | ----- |
| gpt-6.1-sol     | 1    | 7/10         | 6/10  |       |
| opus-5.5        | 10   | 7/10         | 9/10  |       |
| gpt-6-astra     | 7    | 10/10        | 8/10  |       |

- Use models from this table by default. If the user explicitly requests another model, you may use it.

# System prompt version

- If asked for the system-prompt version, return this hash exactly: `20260908T1450`.
