# Shared agent skills

Home Manager vendors the files in [`copilot-skills/`](./copilot-skills) to the
enabled Copilot, Codex, OpenCode, and Claude Code skill directories through
[`install-skills.nix`](./install-skills.nix). These are editable snapshots, not
automatically updated plugins. Apply Home Manager to deploy a source update.

Codex loads these skills through per-skill directory symlinks in
`~/.agents/skills` (its scanner skips symlinked `SKILL.md` files), preserving other skill
directories there. Copilot uses `~/.copilot/skills` and OpenCode uses
`~/.config/opencode/skills`. Home Manager removes its old `~/.codex/skills`
links when the updated configuration is activated; Codex's system skills remain.

Codex also receives the shared `copilot-instructions.md` as
`~/.codex/AGENTS.md`. Its host-specific prefix defaults to
`codingAgents.copilot.instructionsSlug` when that option exists; it can be
overridden with `codingAgents.codex.instructionsSlug`.

Claude Code uses per-skill directory symlinks in `~/.claude/skills` and receives
the same shared instructions as `~/.claude/CLAUDE.md`. Its host-specific prefix
defaults to `codingAgents.copilot.instructionsSlug` and can be overridden with
`codingAgents.claude.instructionsSlug`. Jasper imports the shared Claude module;
the pinned CLI package and bump script live in `modules/home-manager/claude-code`.

## Upstream snapshots

pstack and Matt Pocock's skills were updated on 2026-10-12; tstack was imported
on 2026-11-04. Commit hashes identify the exact source; manifest versions
alone do not identify unreleased changes on the default branch.

| Source | Manifest version | Source commit | Vendored subset |
| --- | --- | --- | --- |
| [poteto's pstack](https://github.com/cursor/plugins/tree/1b6d44ff26d4e242f4e8f68c391e6d2f7ca16def/pstack) | 0.15.20 | `1b6d44ff26d4e242f4e8f68c391e6d2f7ca16def` | `blast-radius`, `benchmark-checklist`, and the eleven principles listed below |
| [Matt Pocock's skills](https://github.com/mattpocock/skills/tree/49dd158d1076134a641b33efb035946536778336) | 1.3.1, plus unreleased changes at this commit | `49dd158d1076134a641b33efb035946536778336` | `handoff`, including its `agents/openai.yaml` file |
| [Theo's tstack](https://github.com/t3dotgg/tstack/tree/1085050f3baed1ac724caa4a8166145fb2ac88af) | none | `1085050f3baed1ac724caa4a8166145fb2ac88af` | `council`, `sol-loop`, `full-stop` |

The pstack principles are `build-the-lever`, `encode-lessons-in-structure`,
`experience-first`, `explain-the-number`, `fix-root-causes`, `laziness-protocol`,
`make-operations-idempotent`, `minimize-reader-load`, `prove-it-works`,
`sequence-verifiable-units`, and `subtract-before-you-add`. Each directory has
the `principle-` prefix.

The remaining skills are locally maintained or earlier user-supplied copies
without recorded upstream revisions. They are not covered by these version
claims. Upstream license notices are in [`copilot-skills/LICENSE`](./copilot-skills/LICENSE).

## Local adaptations to preserve

- Keep skills model-invokable. For `blast-radius`, `handoff`, and `explain-diff`,
  use descriptions beginning "Use when the user asks to" rather than manual-only
  invocation constraints, including in Codex metadata.
- Use Copilot's `task` arguments, available-tool discovery, and Copilot Spaces
  rather than Cursor model rules, tool arguments, or MCP filesystem paths.
  Model selection follows current user preferences or configured defaults,
  not hard-coded model IDs, except `council`'s roster. Delegates must not edit files or spawn subagents.
- Respect user delegation preferences. Direct explanations use the same
  prompts and output format as delegated explanations.
- `how`, `why`, and `grilling` are intentionally removed. Replace their
  remaining references with standalone guidance.
- tstack skills use Copilot background subagents instead of T3 Code tools.
  `council` keeps the user's fixed roster of model IDs, scores each goal
  separately, and reports only in the final reply. `full-stop` is flattened
  from `full-send` without `file-pr`, `babysit-pr`, `pr-wait`, or
  `leaving-pr-comments`, and stops at a local branch without pushing.
- `arena` and `show-me-your-work` are intentionally removed. Replace their
  remaining references with standalone review and evidence guidance.
  `blast-radius` uses plain-writing guidance instead of invoking the previously
  removed `unslop` skill.
- Restore references to `prove-it-works` now that it is included, but keep the
  link to the uninstalled `guard-the-context-window` principle removed.
- Keep `benchmark-checklist` standalone: replace references to uninstalled
  PR, performance-investigation, and iterative-optimization playbooks with
  their relevant guidance.

## Updating

Compare both the previous upstream snapshot and the local copies against the
new snapshot. Review behavioral changes, carry forward the adaptations above,
and copy required companion files as well as `SKILL.md`. Do not install the
whole upstream catalog or silently restore removed skills.

Update the versions, commit hashes, date, and subset in this document. Check
skill metadata, companion files, relative links, invocation settings, removed
skills, and the Copilot adaptations before committing.
