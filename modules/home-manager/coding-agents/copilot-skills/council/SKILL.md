---
name: council
description: Use when the user asks for a "council".
---

# Council

Before an audit, address outstanding PR comments, fix known issues, and run
relevant checks. Give the council the updated implementation; do not defer
known fixes until reviews return. If the user wants to discard the
implementation and explore new ideas, skip fixes to code being replaced.

## Councilors

| Councilor | `model` | `reasoning_effort` |
| --- | --- | --- |
| GPT-6 Astra | `gpt-6-astra` | `xhigh` |
| GPT-6.1 Sol | `gpt-6.1-sol` | `xhigh` |
| Opus 5.5 | `claude-opus-5.5` | `xhigh` |

If the user names other councilors, use those. If a councilor is unavailable,
report it instead of substituting.

## Separate scores per goal

Use one council for the request. If it has several goals, ask each councilor
to review and score each goal separately, so one goal's findings do not hide
another's.

## Running a round

Run the three councilors as parallel background subagents. Give each the request and the context
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

Put the results in the final reply only.

```markdown
## Council review

Rounds: 2

| Goal | Councilor | Round 1 | Round 2 |
| --- | --- | --- | --- |
| Fix the crash | Opus 5.5 | 7/10 | 9/10 |
| Fix the crash | GPT-6 Astra | 8/10 | 10/10 |
| Fix the crash | GPT-6.1 Sol | 7/10 | 9/10 |
| Keep the API stable | Opus 5.5 | 6/10 | 9/10 |
| Keep the API stable | GPT-6 Astra | 8/10 | 9/10 |
| Keep the API stable | GPT-6.1 Sol | 7/10 | 8/10 |
```

With a single goal, drop the Goal column.

If a councilor gives no score, write `no score`. Do not invent one.

If you agree with their recommendations, make the changes and request a fresh
review. Continue until all councilors are satisfied.

Do not let repeated reviews cause scope creep. It is your job to keep scope
limited.
