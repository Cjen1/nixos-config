---
name: lean
description: Use when setting up, building, or writing proofs in a Lean 4 project.
---

## Use the global mathlib

Home Manager roots one prebuilt mathlib and its dependencies in the Nix store.
Nix downloads cached binaries or builds once; matching projects share them.

- Reuse the matching shared packages at `~/.local/share/lean-shared`, keeping
  Lake build/dependency trees outside the worktree per the global build-artifact
  policy. Do not run `lean-share` in a watched worktree: it creates in-tree
  dependency symlinks. Use supported external paths; report any blocker.
- Use the Home Manager-provided `lean` and `lake`, not an elan toolchain.
  Projects using other versions must stay separate; do not silently change
  their toolchain, dependency pins or proof sources to force compatibility.
- Do not run `lake update` or `lake exe cache get` on shared projects: they can
  clone dependencies again. Keep `lake-manifest.json` pinned.
- Nix-based projects can use `inputs.nixpkgs.url = "lean-nixpkgs";` to select
  the same pinned packages. A per-project flake is not required for `lean-share`.
- If the project cannot use the shared versions, keep its separate dependency
  cache outside the worktree and tell the user why.

## Proofs

- Reach for `grind` first. Pass it the lemmas it needs (`grind [foo, bar]`)
  or tag reusable facts with `@[grind]`, before writing manual steps.
- Fall back to `simp`, `omega`, or explicit terms when `grind` fails or is
  slow, and keep the step small.
