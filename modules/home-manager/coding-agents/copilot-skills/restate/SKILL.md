---
name: restate
description: "Restate what you said and did since a starting point, in plain, self-contained words. Use for /restate, optionally followed by where to start."
argument-hint: "Optional: where to start, such as a time, a message, or an event"
---

# Restate

Restate everything you told the user or did since the starting point, in plain, direct words, like one person catching up another.

Start where the user says after `/restate`: a time, a message, or an event. Otherwise start at their last message that set a direction, made a request, or made a decision. `/restate`, earlier restatements, acknowledgements such as "ok", notifications, and subagent results do not count.

Write for someone who knows the basics of the field but has not read this chat. Define each piece of jargon, alias, and setting the first time it appears: write "cs1, the first Codespace", not "cs1". State specific configurations, values, and versions exactly, with what each one controls. Copy paths, commands, numbers, hashes, and URLs verbatim when you keep them, and leave out any the user does not need.

Use only what this chat already says. Do not run tools, do new work, or answer new questions. Keep each caveat as uncertain as it was.

Lead with what changed and where things stand. Then say what failed or is unfinished. End with each decision waiting on the user, with the pick you gave earlier, if any. Leave out steps that changed nothing. Use short sentences and no preamble.

If nothing happened since the starting point, say so and stop.
