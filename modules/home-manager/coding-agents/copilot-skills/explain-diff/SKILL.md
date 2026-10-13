---
name: explain-diff
description: "Explain a PR or a set of changes as a guided, step-by-step walkthrough: an HTML page with the diff on the left and comments on the right, ordered the way an engineer would implement the change from scratch. Invoke manually, e.g. '/explain-diff https://github.com/org/repo/pull/123' or '/explain-diff main..my-branch'."
argument-hint: "PR URL/number, or a BASE..HEAD range"
disable-model-invocation: true
---

# Explain diff

Turn a diff into a guided walkthrough the user can step through. The tool in this directory renders it; your job is the explanation: which steps, in what order, anchored to which lines.

The reader should finish able to re-implement the change themselves. Not just "what changed in each file", but what the change is for, what it introduces, and how each edit follows from that.

The user invoked this deliberately and expects the finished page, not a conversation. Don't ask what they want: the argument tells you which changes, and this file tells you how to explain them. If there's no argument, explain the current branch against its upstream merge-base and say so. Do the whole job, render, host, and hand back the URL.

## 1. Pin the range

Work against fixed commits, not a moving branch.

- **PR**: fetch it into a worktree so you can read files at head without touching the user's checkout.
  ```bash
  git fetch --quiet origin refs/pull/<N>/head
  git worktree add --detach .worktrees/<N> FETCH_HEAD
  base=$(git -C .worktrees/<N> merge-base HEAD origin/<target-branch>)
  ```
  Use the merge-base, not the target branch tip, or unrelated commits from main show up in the diff. `gh pr view <N> --json baseRefOid,headRefOid,title,body` gives the PR's own view of both.
- **Local range**: resolve both ends to hashes with `git rev-parse`.

## 2. Understand the change before writing anything

Read the whole diff and the PR description. Read enough surrounding code to know what each touched function did before. Then answer, in one sentence each:

- **The aim.** What problem does this solve? What was slow, wrong, or missing?
- **The key idea.** The one structural move everything else follows from: a new data structure, an inverted lookup, a new invariant, a moved responsibility.
- **What stays the same.** The behaviour the change must preserve. This is what tests are protecting.

If you can't answer these, you can't order the walkthrough. Use the `how` skill for unfamiliar subsystems.

## 3. Order the steps by implementation, not by file

The theory of mind: **how would an engineer build this change from an empty diff?** They don't start at the top of file A. They start with the idea, build the new pieces, wire them in, switch the behaviour over, then prove it.

A typical shape. Reorder, merge, or skip to fit the change:

1. **The aim and the key idea.** Anchor this to the central new code, such as a new type, function, or config.
2. **New data structures**, one step each. What they represent and the invariant they must maintain.
3. **Their operations**: add/remove/query, one function per step if they're subtle. Explain the return values and the failure paths.
4. **Plumbing**: how the new pieces reach the code that needs them, such as constructor arguments and fields.
5. **Each call site that must keep the invariant**, grouped by the flow it belongs to. For important functions, go branch by branch. Say why each branch needs the change, or why it doesn't.
6. **Lifecycle and cleanup**: creation, deletion, expiry, error paths. These are easy to forget, so batch them where the reader can check they're complete.
7. **The switch-over**: the place that now *uses* the new structure instead of the old way. This is usually the point of the whole change, but it only makes sense after the invariant is established.
8. **Proof**: tests, oracles, benchmarks. What each one would catch.
9. **Docs, changelog, and other cleanup**, batched at the end.

Write each comment **fractally**:

- The **first line is the step's title**, shown in the step selector. Make it a complete thought: "Remove only the finished role", not "remove()".
- The **first paragraph** says what this step does and why, in plain words.
- **Later paragraphs** give mechanics: per-branch behaviour, ordering constraints, failure handling, and what would break if this step were skipped.

Rules:

- Explain *why*, not just *what*. The diff already shows what.
- Point out what the diff doesn't show: behaviour preserved implicitly, ordering that matters, a call site that needed no change and why.
- Mark inference as inference. If the PR doesn't say why something was done, say "appears to" rather than inventing a reason.
- Keep ranges tight: a function, a branch, or a few lines. A step that spans 200 lines isn't a step.
- Aim for roughly 8-25 steps. A one-line fix needs one or two.

### Example: the order, not the file order

A PR that stopped a cache scanning every retained request on each ledger reply. It added a reverse index (`seqno -> handles + reason bits`). In patch order the struct is near the top, the call sites are scattered through `adjust_ranges`, `populate_receipts`, and `erase_request`, and the key loop change is two-thirds of the way down. The walkthrough went:

1. *Start with the missing lookup*: the old reply loop asks every request; build the inverse. Note why reasons are bits: one handle can need an entry for several reasons.
2. *Define how membership changes*: `add`, what each return value means, and the allocation-failure path.
3. *Define the inverse*: `remove` clears one reason, not the consumer.
4. *The two read operations* the reply path will need.
5. *Plumbing*: give each request the index and its handle.
6. *Make insertion safe*: the helper that keeps forward and reverse maps in step.
7. *Range adjustment, branch by branch*.
8. *Receipt discovery, branch by branch*.
9. *Secret-waiter transitions as one setter*.
10. *Close the lifecycle*: deletion and expiry.
11. *Switch the first scan* (deserialisation's predicate).
12. *Freeze consumers at the publication boundary*: where the snapshot is taken and why there.
13. *Replace the loop, not the behaviour*: the main switch-over, line by line.
14. *Make the performance claim observable*: the counter.
15-18. *Oracle test, targeted transition tests, scaling benchmark, e2e + docs*.

The switch-over is step 13, not step 1, even though it is the reason for the PR. It only reads as safe once steps 2-10 have established that the index is complete.

## 4. Write the comments file

JSON list, in walkthrough order: `[path, start_line, end_line, text]`.

```json
[
  ["src/cache.h", 222, 240, "Build the reverse lookup\n\nThe cache knew which entries each request needed, but not which requests need an entry. Add the inverse...\n\nRoles are independent bits because..."],
  ["src/cache.h", 242, 270, "Register a reason to receive an entry\n\n..."]
]
```

- `path` is as it appears in the diff (the head-side path for renames).
- Lines are **head-side** (the file at HEAD), 1-based, inclusive. For pure deletions, anchor on the nearest surviving line. Deleted lines take the line number of the next head line. To comment on a deleted file, use line 1 to line 1.
- Comments may also anchor on unchanged lines, such as a call site that didn't need changing. Those lines are shown automatically.
- Save it next to the output, such as `<session files>/explain-<N>/comments.json`, so it can be edited and rerun.

## 5. Render

```bash
uv run ~/.copilot/skills/explain-diff/walkthrough.py "$base" "$head" comments.json \
  --repo <worktree-or-repo> --title "<repo>#<N>: <PR title>" -o <dir>/index.html
```

`uv` installs the tree-sitter dependency on first run. You can also call it from Python: `render_walkthrough(repo, base, head, comments, output, title)`.

The page has the diff on the left and comments on the right. It also includes:

- a step selector and **Previous**/**Next** buttons, plus arrow-key navigation;
- the enclosing namespace, class, function, and test-case lines around each hunk;
- grey `... N lines` folds you can click to expand.

The tool fails if a comment's path is not in the diff or its range is outside the head file. It prints `uncommented changes: <path>: <lines>` for changed lines that no comment covers. Either cover them, often as a batched cleanup step, or make sure leaving them out is deliberate. Rerun until the remaining output is intentional.

## 6. Check it, then host it

1. Open the page and step through every step once. Each note should sit beside the code it describes, and the order should read like building the change. If a step needs a later step to make sense, swap them.
2. Serve it from its directory and open it, following the `html-report` skill:
   ```bash
   python3 -u -m http.server <port> --bind 127.0.0.1 --directory <dir>
   ```
   Run it detached. On WSL, open it with `explorer.exe "http://localhost:<port>/"`, then confirm a `GET /` in the server log.
3. Give the user the URL plus a two- or three-line summary: the aim, the key idea, and anything risky you noticed on the way. Don't restate the walkthrough.
