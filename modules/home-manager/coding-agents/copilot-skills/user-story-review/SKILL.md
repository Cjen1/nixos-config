---
name: user-story-review
description: Use when the user asks to improve documentation.
---

Review prose by reading it as its readers would: pick a small set of reader
goals, have cheap subagents read as each reader, address their feedback with
minimal edits that balance the goals.

## Phases

- Goal discovery
- Iteration (Read, Address, repeat)
- Finish

## Goal discovery

A **reader goal** is a specific reader with a specific task: who they are, what
context they arrive with, what they are trying to do, and what they should be
able to say they learned. "Operator capturing and replaying a trace for the
first time" is a goal; "someone reading the README" is not.

Pick the **minimal useful set**, 2–10 goals, preferring goals that pull the text
in different directions. Goals may be minor variations in focus or context (new
vs experienced user, happy path vs failure, trusting vs skeptical reader) when
the variation changes what the reader notices.

## Iteration

### Read

Spawn several cheap, low-effort subagents per goal in parallel, each reading
**as if they are that reader**, with slightly varied prompts (procedure
walkthrough, failure scenario, pure teachback). Every prompt asks for:

- **Teachback**: for your goal, what did you learn; summarise what you took
  away.
- **Snags**: ambiguities, contradictions, wrong paths, placeholder inputs
  mistaken for generated files, command-order ambiguity, "meaningless fluff"
  (history and repetition obscuring the task).

Constraints: material inline or at repository paths, never temporary files
outside the worktree; read-only (no edits, comments, commits, builds,
installs, subagents), source consulted only to verify a specific claim; state
what is out of scope so they do not ask for it.

### Address

Collect findings across all goals, then for each:

- **Verify** disputed facts against source; a confident claim is a lead, not a
  fact.
- **Push back** on irrelevant or incorrect feedback; record the rejection and
  reason in one line.
- **Minimise** the text: delete repetition, stale history and repeated
  disclaimers, or add a precise link, before writing new sections.
- **Balance objectives**: when goals conflict, decide which reader the passage
  serves, move the other's material to where they will look, say so. Do not
  satisfy one reviewer by breaking another's teachback.
- Keep each edit **minimal**: a one-sentence finding gets a one-sentence change.

Repeat Read until the reviewers are happy or the remaining findings are ones
you deliberately rejected. Do not spawn rounds for feedback you have already
decided not to act on.

## Finish

Run **one fresh, unprimed reader** per goal, with no sight of earlier findings
or fixes, doing a plain teachback. If a workflow is documented as runnable,
have one reader attempt the commands; reading-only approval shows consistency,
not that the steps work.

Report: goals used; net change and main deletions; rejected findings and why;
total reviewer launches and what the final approvals cover.
