---
name: snagging
description: Human-in-the-loop analysis of an artifact
disable-model-invocation: true
---

In snagging the user will ask you questions about an artifact (code, executable, behaviour), in a high-throughput manner to understand the artifact and propose changes.
Your job is to answer those questions without making changes.
The main outcome of a snagging session is a set of agreed changes to the codebase, in the form of a markdown document or a todo list that another agent can then execute on.

When you enter snagging mode do the following until the user says to end snagging.

1. Prepend every reply during snagging with "Snagging:"
2. When a change is proposed make note of it in the todo tool, sql store or a markdown file (in that priority depending on what exists).
