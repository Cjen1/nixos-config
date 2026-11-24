---
name: council
description: Use when the user asks for a "council", optionally followed by a number or "all".
---

# Council

Before an audit, address outstanding PR comments, fix known issues, and run
relevant checks. Give the council the updated implementation; do not defer
known fixes until reviews return. If the user wants to discard the
implementation and explore new ideas, skip fixes to code being replaced.

## Councilors

Councilors are listed in priority order.

| Priority | Councilor | `model` | `reasoning_effort` |
| --- | --- | --- | --- |
| 1 | GPT-6.2 Astra | `gpt-6.2-astra` | `xhigh` |
| 2 | Opus 5.5 | `claude-opus-5.5` | `xhigh` |
| 3 | Gemini 4 Neon | `gemini-4-neon` | `xhigh` |
| 4 | MAI Code 2 | `mai-code-2` | `xhigh` |

A number after "council" sets its size: use that many councilors, taken from
the top of the list. "Council 1" is GPT-6.2 Astra alone; "council 3" is GPT-6.2
Astra, Opus 5.5, and Gemini 4 Neon. "Council all", a number of 4 or more, or
no number uses every councilor.

If the user names other councilors, use those. If a councilor is unavailable,
report it instead of substituting.

## Separate scores per goal

Use one council for the request. If the user does not state the goals, infer
them from the prior discussion and list them in each councilor's brief. If the
request has several goals, ask each councilor to review and score each goal
separately, so one goal's findings do not hide another's.

Split a large goal into smaller subgoals and score each one. A single score for
a broad goal hides where the work falls short; subgoal scores give more
specific feedback.

## Running a round

Run the selected councilors as parallel background subagents. Give each the request and the context
it needs: repo path, base, diff command, intent, what is out of scope, and
check results. For review or feedback, keep them read-only. A timeout, error,
or missing reply is not approval.
Keep each councilor's findings and scores distinct.

Summarize the useful findings, disagreements, and recommended next steps.

## Code review

Ask each councilor for a score out of 10 for each goal. Count each full review
pass as one round. A fresh review after fixes starts a new round: send the
same councilors what you fixed, what you declined and why, and the change
since the last round.

Put the results in the final reply only. Give each goal its own table, with a
row per councilor and a column per round.

```markdown
## Council review

Rounds: 2

### Fix the crash

| Councilor | Round 1 | Round 2 |
| --- | --- | --- |
| GPT-6.2 Astra | 8/10 | 10/10 |
| Opus 5.5 | 7/10 | 9/10 |
| Gemini 4 Neon | 7/10 | 9/10 |

### Keep the API stable

| Councilor | Round 1 | Round 2 |
| --- | --- | --- |
| GPT-6.2 Astra | 8/10 | 9/10 |
| Opus 5.5 | 6/10 | 9/10 |
| Gemini 4 Neon | 7/10 | 8/10 |
```

With a single goal, give one table under that goal's heading.

If a councilor gives no score, write `no score`. Do not invent one.

If you agree with their recommendations, make the changes and request a fresh
review. Continue until all councilors are satisfied.

Do not let repeated reviews cause scope creep. It is your job to keep scope
limited.
