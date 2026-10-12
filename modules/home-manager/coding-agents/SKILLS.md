# Shared agent skills

Home Manager vendors the files in [`copilot-skills/`](./copilot-skills) to the
enabled Copilot, Codex, and OpenCode skill directories through
[`install-skills.nix`](./install-skills.nix). These are editable snapshots, not
automatically updated plugins. Apply Home Manager to deploy a source update.

## Upstream snapshots

Updated on 2026-10-12. Commit hashes identify the exact source; manifest versions
alone do not identify unreleased changes on the default branch.

| Source | Manifest version | Source commit | Vendored subset |
| --- | --- | --- | --- |
| [poteto's pstack](https://github.com/cursor/plugins/tree/1b6d44ff26d4e242f4e8f68c391e6d2f7ca16def/pstack) | 0.15.20 | `1b6d44ff26d4e242f4e8f68c391e6d2f7ca16def` | `how`, `why`, `blast-radius`, `benchmark-checklist`, and the eleven principles listed below |
| [Matt Pocock's skills](https://github.com/mattpocock/skills/tree/49dd158d1076134a641b33efb035946536778336) | 1.3.1, plus unreleased changes at this commit | `49dd158d1076134a641b33efb035946536778336` | `grilling`, `handoff`, including their `agents/openai.yaml` files |

The pstack principles are `build-the-lever`, `encode-lessons-in-structure`,
`experience-first`, `explain-the-number`, `fix-root-causes`, `laziness-protocol`,
`make-operations-idempotent`, `minimize-reader-load`, `prove-it-works`,
`sequence-verifiable-units`, and `subtract-before-you-add`. Each directory has
the `principle-` prefix.

The remaining skills are locally maintained or earlier user-supplied copies
without recorded upstream revisions. They are not covered by these version
claims. Upstream license notices are in [`copilot-skills/LICENSE`](./copilot-skills/LICENSE).

## Local adaptations to preserve

- Keep the eleven principles, `benchmark-checklist`, `how`, and `why`
  model-invokable. Keep `blast-radius`
  and `handoff` user-invoked, and retain Matt's Codex invocation metadata.
- Use Copilot's `task` arguments, available-tool discovery, and Copilot Spaces
  rather than Cursor model rules, tool arguments, or MCP filesystem paths.
  Model selection follows current user preferences or configured defaults,
  not hard-coded model IDs. Delegates must not edit files or spawn subagents.
- Respect user delegation preferences. Direct explanations use the same
  prompts and output format as delegated explanations.
- Bundle every reference file required by `how` and `why`. Follow upstream's
  removal of `how`'s critique mode and its five-tier confidence framework in
  `why`.
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
