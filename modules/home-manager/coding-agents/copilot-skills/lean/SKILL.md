---
name: lean
description: Use when setting up, building, or writing proofs in a Lean 4 project.
---

## Use the global mathlib

Home Manager roots one prebuilt mathlib and its dependencies in the Nix store.
Nix downloads cached binaries or builds once; matching projects share them.

- Run `lean-share /path/to/project` before building. It validates the exact Lean,
  mathlib and transitive dependency revisions, then links `.lake/packages` entries
  and `.lake/package-overrides.json` to the shared immutable packages.
- For existing dependency clones, use `lean-share --replace /path/to/project`.
  It removes only clean matching dependency checkouts, preserves project sources
  and `.lake/build`, and refuses active builds, local dependency edits, version
  mismatches and custom package overrides. `--dry-run` performs checks only.
- Use the Home Manager-provided `lean` and `lake`, not an elan toolchain.
  Projects using other versions must stay separate; do not silently change
  their toolchain, dependency pins or proof sources to force compatibility.
- Do not run `lake update` or `lake exe cache get` on shared projects: they can
  clone dependencies again. Keep `lake-manifest.json` pinned.
- After `lake build`, shared `.lake/packages` entries must remain symlinks into
  `/nix/store`; only the project's own build outputs should be local.
- Nix-based projects can use `inputs.nixpkgs.url = "lean-nixpkgs";` to select
  the same pinned packages. A per-project flake is not required for `lean-share`.
- Fall back to a project-local dependency cache only if it cannot use the
  shared versions, and tell the user why.

## Proofs

- Reach for `grind` first. Pass it the lemmas it needs (`grind [foo, bar]`)
  or tag reusable facts with `@[grind]`, before writing manual steps.
- Fall back to `simp`, `omega`, or explicit terms when `grind` fails or is
  slow, and keep the step small.
