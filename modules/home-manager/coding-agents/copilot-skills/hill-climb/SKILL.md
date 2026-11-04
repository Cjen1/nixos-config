---
name: hill-climb
description: Use when the user explicitly asks for a 'hill climb'.
---

# Hill Climb

Do not do this unless the user has explicitly asked for a hill climb.

Improve the current work against an agreed goal: score it, make changes that
raise the scores, and repeat.

## 1. Goal

You need an existing goal made of one or more objectives. If there is no goal,
stop now and ask the user for one. If the goal or any objective is unclear,
refine it with the user before starting.

For each objective, agree on the dimensions it is scored on, for example
correctness, simplicity, or readability. Keep these dimensions fixed for the
whole climb so the scores stay comparable between rounds.

## 2. Score

For each objective, run a separate council (see the `council` skill) to review
the current state against that objective only. Ask each councilor to score
every dimension out of 10. For each score, they give the evidence and the
change that would raise it most.

## 3. Climb

Make the changes that raise the scores most, smallest first. Prove each
change. Do not trade one objective for another; if a change would lower
another objective's score, find a different change or ask.

Send the next round to the same councils. Keep a table of scores per
objective, dimension, councilor, and round.

## 4. Stop

Stop when every council is satisfied, or when scores stop rising for a round.
Report the score table, what changed, and the remaining gaps per objective.

Keep scope to the goal. Reviewers will suggest more; decline what the goal
does not need and list it as follow-up.
