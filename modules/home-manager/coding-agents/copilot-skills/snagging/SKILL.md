---
name: snagging
description: Use when the user explicitly says "snagging".
---

The user is manually reviewing code and wants to make a bunch of small changes
over multiple turns. 

## Procedure

Move through the following stages.

- Snagging
- Questions
- Cleanup

## Snagging

The user will provide multiple comments over multiple turns of things they want explained, or changed.

For each user comment do one of the following:

- A small, focused change.
- A queued todo for a larger change or refactoring.
- A queued question.
- Concise inline text explaining or answering something for the user.

Do not run tests, linters, or compilers unless the user explicitly asks.
Do not turn a small comment into a broad refactoring or start queued work without direction.

Acknowledge the outcome briefly, without repeating the entire backlog.

Continue across turns until the user says they are done or says "stop snagging".

## Questions

Interview the user on each of the questions one at a time.
Map the questions as a design tree, each question should produce decisions which may branch into further questions and corresponding decisions.


Interview the user until you reach a shared understanding on the outstanding questions / decisions. 
Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**.
The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet.
Ask the whole frontier in one round: number each question and give your recommended answer. 
Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Word each question so "yes" accepts your recommended answer.

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them.
Recompute the frontier and ask the next round.
A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's.
When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself.
Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now.
The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every major branch of the design tree visited.
Do not act on it until the user confirms you have reached a shared understanding.

This process will produce work items which should be added to the todo list.

## Cleanup

Carry out the queued todo items in dependency order.
Keep changes focused and update each item's status as it is completed.
If an item needs an unresolved decision, surface the question and leave dependent work blocked rather than guessing; continue independent work where possible.

Leave testing, linters, building with compilers etc to the end unless it is necessary to make a change.
This allows you to do the bulk of the work without getting bogged down by tooling.

Once complete, report what has been done and any unresolved items.
