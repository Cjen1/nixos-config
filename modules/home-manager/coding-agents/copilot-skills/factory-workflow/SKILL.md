---
name: factory-workflow
description: "Use for substantial multi-agent work or independent review. Create or reuse a task-specific Copilot factory."
---

# Factory workflow

1. Read the factory guide through `factories_manage`. Reuse a suitable registered factory or author one for this task.
2. Give workers bounded tasks, relevant evidence, and acceptance checks. Keep parallel edits in separate paths. Do not let workers spawn subagents.
3. Use the model table in `copilot-instructions.md`, or another model explicitly requested by the user. Prefer cheap models for mechanical work, taste >= 7 for user-facing work, and stronger models when results fall short. Check supported model IDs.
4. For substantial work, fan out reviewers with distinct lenses. For explanations, gather evidence first, then review correctness, completeness, and alternative explanations.
5. Run the factory with user approval. Set resource limits only when specified by the user. Handle failed workers explicitly.
6. Inspect the result, coalesce evidence-backed findings, and verify the deliverable. Resume interrupted work by run ID rather than starting over.

Keep small tasks direct. If factory tools are unavailable, say so.
