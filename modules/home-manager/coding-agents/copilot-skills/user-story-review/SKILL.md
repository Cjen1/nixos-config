---
name: user-story-review
description: Use when the user asks to review or improve documentation, READMEs, or a PR description against reader goals or user stories.
---

Review prose by reading it as its readers would: pick a small set of reader
goals, have cheap subagents read as each reader, address their feedback with
minimal edits that balance the goals.

Optimise the resulting text, not review cost or pass count. Extra passes,
even unexpectedly expensive ones, are fine; do not add rules to avoid them.

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

Spawn three cheap, low-effort subagents per goal in parallel (fewer for a
short document), each reading **as if they are that reader**. Keep the goal
fixed and vary the approach so each surfaces different snags: procedure
walkthrough, failure scenario (a plausible failure on that reader's task),
teachback-led. Every prompt asks for:

- **Teachback**: for your goal, what did you learn; summarise what you took
  away.
- **Snags**: ambiguities, contradictions, wrong paths, placeholder inputs
  mistaken for generated files, command-order ambiguity, "meaningless fluff"
  (history, repetition, or other goals obscuring the task). For ambiguity, give two
  plausible interpretations and how they materially affect the reader's goal.
- **Value**: what parts of the text were useful, what parts were not.

Use read-only agents.
State what is out of scope (new features, machine-specific setup, exhaustive formal
guarantees) so they do not ask for it.

### Address

Group duplicate findings into distinct issues, then for each:

- **Judge the teachback**, not the complaint. Fix demonstrated misunderstandings,
  not every request for explicitness. A usable plan followed by "NO, a scenario
  detail was unspecified" is not necessarily a writing defect. Leave reasonable
  execution choices to the agent; examples are not requirements.
- **Verify** disputed facts against source; a confident claim is a lead, not a
  fact.
- **Push back** on irrelevant or incorrect feedback; record the rejection and
  reason in one line for the report.
- **Minimise** the whole text. Prefer deletion or replacement
  to addition.
- **Every statement must serve a purpose**: if every reader says a section was
  not useful, remove it.
- **Balance objectives**: when goals conflict, decide which reader the passage
  serves, move the other's material to where they will look, and note the
  trade-off in the report. Do not satisfy one reviewer by breaking another's
  teachback.

Repeat Read, until no issue remains that is not deliberately rejected.

## Finish

Run **one fresh, unprimed reader** per goal, with no sight of earlier findings
or fixes, doing a plain teachback and stating whether their goal was met. If a
workflow is documented as runnable, one of them attempts the commands (the
read-only constraint does not apply to this attempt); reading-only approval
shows consistency, not that the steps work. New findings go back through
Address and a repeat of Finish for the affected goals only.

Report: goals used; net change and main deletions; rejected findings and why;
total reviewer launches across all phases and what the final readers covered
(including any commands that could not be attempted).
