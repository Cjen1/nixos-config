---
name: council
description: Use when the user says "council". Gets review or feedback from three models and loops until they agree.
---

# Council

Before an audit, address outstanding PR comments, fix known issues, and run
relevant checks. Give the council the updated implementation; do not defer
known fixes until reviews return. If the user wants to discard the
implementation and explore new ideas, skip fixes to code being replaced.

## Councilors

| Councilor | `model` | `reasoning_effort` |
| --- | --- | --- |
| Opus 5.5 | `claude-opus-5.5` | `high` |
| GPT-6.1 Sol | `gpt-6.1-sol` | `max` |
| GPT-6.1 Terra | `gpt-6.1-terra` | `max` |

If the user names other councilors, use those. If a councilor is unavailable,
report it instead of substituting.

## One council per goal

Each distinct goal gets its own council of three fresh councilors. Never send
a different goal to an existing councilor. If the request has several
independent goals, run a separate council for each. Later rounds on the same
goal go to that goal's councilors.

## Running a round

Start all three councilors in one response with the `task` tool:
`agent_type: "general-purpose"`, `mode: "background"`, and the `model` and
`reasoning_effort` above. Save each `agent_id`. Wait for the completion
notifications, then read each reply once with `read_agent`. Do not poll. A
timeout, error, or missing reply is not approval.

Give each councilor the request and the context it needs: repo path, base,
diff command, intent, what is out of scope, and check results. For review or
feedback, tell them: "Review only. Do not edit, commit, push, comment on PRs,
or start subagents."

Summarize the useful findings, disagreements, and recommended next steps.

## Code review

Ask each councilor for a score out of 10. Count each full review pass as one
round. A fresh review after fixes starts a new round: send it to the same
councilors with `write_agent`, with what you fixed, what you declined and why,
and the change since the last round. Read the new reply with `read_agent`
using `since_turn`. If a councilor has failed or been cancelled, start a fresh
one for that seat and give it the ledger.

If the work has an open PR, put the results in its description, above the
model and harness line at the end. Edit the description; do not post a
comment. Otherwise put the same results in the final reply only.

```markdown
## Council review

Rounds: 2

| Councilor | Round 1 | Round 2 |
| --- | --- | --- |
| Opus 5.5 | 7/10 | 9/10 |
| GPT-6.1 Sol | 8/10 | 10/10 |
| GPT-6.1 Terra | 7/10 | 9/10 |
```

If a councilor gives no score, write `no score`. Do not invent one.

If you agree with their recommendations, make the changes and request a fresh
review. Continue until all councilors are satisfied.

Do not let repeated reviews cause scope creep. It is your job to keep scope
limited.
