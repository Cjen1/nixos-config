---
name: lean
description: Use when setting up, building, or writing proofs in a Lean 4 project.
---

## Use the global mathlib

A full mathlib checkout costs about 8GB per project, so share the copy in the
Nix store instead.

- Take nixpkgs from the `lean-nixpkgs` flake registry entry
  (`inputs.nixpkgs.url = "lean-nixpkgs";`). Home Manager pins it to one
  revision, so every project uses the same mathlib store path.
- Take Lean and mathlib from that revision's `leanPackages` (`lean4`,
  `mathlib`), not from elan. Match `lean-toolchain` and the mathlib `rev` in
  the lakefile to those versions.
- Point Lake at the store copy with `.lake/package-overrides.json`, as
  `buildLakePackage` does, rather than cloning mathlib. Working example:
  `~/repos/msfp/flake.nix`. Copy its `packageOverrides` and `shellHook`.
- Do not run `lake update` or `lake exe cache get`: they ignore the overrides,
  clone mathlib, and fill `.lake/packages`. To bump, edit mathlib's `rev` and
  `inputRev` in `lake-manifest.json` by hand. Get the commit with
  `git ls-remote https://github.com/leanprover-community/mathlib4 <tag>`.
- Check it worked: after `lake build`, `.lake/packages` should not exist and
  `.lake` should be a few MB.
- Fall back to `lake exe cache get` only if the project cannot use the
  pinned versions, and tell the user why.

## Proofs

- Reach for `grind` first. Pass it the lemmas it needs (`grind [foo, bar]`)
  or tag reusable facts with `@[grind]`, before writing manual steps.
- Fall back to `simp`, `omega`, or explicit terms when `grind` fails or is
  slow, and keep the step small.
