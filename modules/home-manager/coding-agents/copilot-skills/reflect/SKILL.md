---
name: reflect
description: Review the active session through three independent lenses, surface durable lessons, and route each lesson to a concrete structural or skill change. Use when the user says reflect.
disable-model-invocation: true
---

# Reflect

Mine the current conversation for durable lessons, then route them into structural changes or skill edits.

## Process

### 1. Build the evidence packet

Summarize the active session from the current timeline. Include the user's goal, decisions, corrections, failed approaches, tool failures, successful path, files changed, and verification evidence. Quote or cite the relevant turn where possible.

If earlier sessions matter, query them with `session_store_sql`. Restrict the query to the current repository and a short time window. Do not search unrelated repositories or users' sessions.

### 2. Run three reviews in parallel

Launch three read-only review tasks in one response. Use the available `task` tool with `agent_type: general-purpose`, model `gpt-5.6-sol`, and the same evidence packet. Tell each reviewer not to edit files or launch subagents.

Give each reviewer one lens:

- **Judgment.** Find bad assumptions, avoidable complexity, missed tradeoffs, and decisions that should change future behavior.
- **Tooling.** Find repeated manual work, brittle commands, missing checks, and lessons better enforced by code or automation.
- **Divergent.** Challenge the apparent lesson, look for alternative explanations, and identify useful lessons the other lenses may miss.

Each finding must include evidence, the durable lesson, its expected reuse, and a proposed destination. Reject one-off preferences and conclusions unsupported by the session.

### 3. Synthesize

Launch one read-only `general-purpose` task on `gpt-5.6-sol`. Give it the evidence packet and all three reviews. Require three lists:

- **Accepted.** Evidence-backed, reusable lessons with a concrete destination and exact proposed change.
- **Rejected.** Plausible findings that are weak, redundant, too specific, or contradicted by evidence.
- **Backlog.** Lessons that belong in lint rules, scripts, metadata, runtime checks, or other structural enforcement.

The synthesizer must merge duplicates, preserve disagreements, and spot-check every accepted citation against the evidence packet.

### 4. Prefer structural enforcement

Move any lesson from Accepted to Backlog when a lint rule, script, metadata flag, type constraint, or runtime check would enforce it more reliably. Follow the **principle-encode-lessons-in-structure** skill.

### 5. Get approval, then apply

Present the full Accepted, Rejected, and Backlog lists. Wait for explicit approval before changing shared skills or instruction files.

For approved items:

- Make small edits directly.
- For a substantial skill change, inspect existing skill conventions, make the smallest coherent edit, and validate the frontmatter and references.
- Create a new skill only when no existing skill or structural mechanism fits.
- File backlog work in the repository's existing tracker when one is available. Do not invent a tracker.

### 6. Report

Return a short list of edits applied, structural work filed, and rejected findings. Name each changed path or issue.
