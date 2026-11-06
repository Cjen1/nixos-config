---
name: full-stop
description: Use when the user says "full stop", even as a closing "Full stop." that reads like emphasis. Builds an agreed solution to high quality without supervision and stops just before filing a PR.
---

# Full Stop

The user has agreed the rough shape of the solution and is not watching.
Build it, prove it, review it, and stop with a local branch ready for the
user to file as a PR. Your updates go unread until you stop, so stay active
until the handoff.

## Grant

An explicit "full stop" request lets you, for this task only:

- Create a branch for this task and commit to it.
- Rebase that branch onto the latest default branch and fix conflicts.
- Use the test methods that Proof needs without asking first, even where a
  project file says to ask first or to leave testing to the user. This
  includes running the app or a dev server, browser automation, and
  screenshots. Rules about *how* to test still apply.

Do not push, open a PR, or comment on GitHub unless the user separately asks.
Never merge or touch the default branch.
The grant does not cover anything under "Asking", and it does not bypass a
harness approval prompt.

## Steps

1. **Build.** Implement the agreed shape with the smallest change that works.
   Fix the case that happened, not every case that could. If you are on the
   default branch, create a branch first.
2. **Prove it.** Get proof for every change. See "Proof".
3. **Review.** Use the `sol-loop` skill. Prove each fix it leads to.
   Run `user-story-review` on any text added or changed, including docs,
   comments, and user-facing copy. If a PR already exists, review its
   description too. If separately asked to open a draft PR, review its
   description before opening it.
4. **Check readiness.** All of these hold on the final commit:
   - Proof covers the whole diff against the default branch.
   - The checks the repo's CI runs pass locally, or you say which cannot run.
   - sol-loop agreed, or the disputed items are written up for the user.
   - The branch is rebased onto the latest `origin/<default-branch>`. Recheck
     proof after behavior changes or meaningful conflict fixes.
   - The working tree is clean, and the branch holds only this task's commits.
5. **Hand off.** Report the branch, `git log --oneline <base>..HEAD`, the
   diffstat, your proof, the sol-loop outcome, each decision you made, and
   remaining risks. Include a draft PR title and description; use the `to-pr`
   skill for their format, then run `user-story-review` on the draft text.

## Proof

Proof is evidence you observed yourself in this session: command output, a
reproduction, a screenshot. Use the most direct proof the change allows:

- Reproduce the original failure, apply the fix, then watch the same
  reproduction pass.
- Run the checks that the repo's CI runs (typecheck, lint, tests).
- Add one focused test that fails without the fix, when the behavior has none
  and the repo has a test setup.
- For UI and runtime behavior, run the app and look at the change. Green
  mocked tests do not prove that the user experience works. Save screenshots
  and list their paths in the handoff.

If you cannot prove a change, you do not have full confidence. Ask.

## Asking

Ask only when you cannot continue alone:

- You cannot prove the change.
- The agreed shape turns out to be wrong, or the goal is ambiguous in a way
  that changes the result.
- The next step is outside the grant: deleting data, touching production,
  changing things outside the repo, or pushing.

To ask, stop safely and start your final message with the question. Include
the context, what blocks you, and the options with your recommendation first.
Decide everything else yourself with sensible defaults, and list those
decisions in the handoff.
