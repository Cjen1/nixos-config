---
name: hill-climb
description: Use when the user explicitly asks for a 'hill climb'.
---

# Hill Climb

Do not do this unless the user has explicitly asked for a hill climb.

You need an existing goal. If there is none, stop now and ask for one. If the
goal is unclear, refine it with the user before starting.

Use a council (see the `council` skill) to review the current state against
each objective in the goal, scoring each separately. Splitting scores into
dimensions gives more useful feedback. Then make changes that improve those
scores, and repeat until the scores stop improving.

Keep scope to the goal.
