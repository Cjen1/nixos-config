# HTML reports

- When producing an HTML report, link to the files and specific lines it references wherever that helps the reader jump to the source. Use the `vscode://vscode-remote/...` form from the host instructions.
- Also include a link to open the relevant workspace.

# Code style

- Follow YAGNI. Build what the current task needs, not what it might need later, but highlight substantial tradeoffs.
- Sequence work into minimal verifiable units. Make the smallest independently testable change, verify it, then move to the next. Order commits so a reviewer can follow the evidence.

# General preferences

- A question from the user does not mean that something is wrong and needs to be fixed.
- DO NOT use the question or multiple-choice tool. Ask in structured but natural language instead, with the options laid out plainly when there are any.
- When reporting information to me, be extremely concise and sacrifice grammar for concision.

# Picking the right models for workflows and subagents

Rankings, higher = better. Cost reflects the time cost of different APIs, not listed price. Intelligence is how hard a problem you can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy editing.

| model           | cost | intelligence | taste | notes |
| --------------- | ---- | ------------ | ----- | ----- |
| gpt-5.6-sol     | 7    | 9            | 6     |       |
| opus-5          | 4    | 6            | 9     |       |
| gemini-4.8-flash| 8    | 5            | 7     |       |
| gpt-6-astra     | 2    | 10           | 8     |       |

- Use models from this table by default. If the user explicitly requests another model, you may use it.
- Keep small tasks direct. Do not create a factory merely to parallelize a few tool calls.
- For proofs, subagent fan-out loses context and expands scope. Instead use low-cost subagents to fill and check disjoint mechanical proofs while the main process continues onto the next objective.

# System prompt version

- If asked for the system-prompt version, return this hash exactly: `20260908T1450`.
