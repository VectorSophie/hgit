# Probe 95 — `hgit statustree`: recursive working-directory status

Status: **PASS.** Closes the last remaining item on ADR 0010's own
"rendering-command awareness of nested trees" list (`See.HC` closed
by probe 93, `Diff.HC` by probe 94 - this closes `Status.HC`).

## What was built

`hgit statustree <repo> <dir_path>` - a real, separate command, not a
change to `hgit status`'s own `find_mask`/`dir_prefix` semantics
(the same CLI-semantics decision `offertree` already made for `offer`,
and `Diff.HC`'s own recursion already made for `diff`).

`StatusTreeWalk` (`Status.HC`) recurses one real directory level at a
time - same generic-per-object-type pattern this project already
established (`Check.HC`'s `CheckMarkReachable`, `See.HC`'s
`SeePrintTreeEntries`, `Diff.HC`'s `DiffPrintTreeChanges`):

- A real subdirectory on disk with a matching, same-typed tree entry -
  recursed into (its own committed subtree resolved via `IndexLookup`,
  same as every other real command).
- A real subdirectory with no tree match at all - recursed against an
  empty tree, so every real file inside gets its own
  `STATUS_NEW <path>` line, not one line naming the directory.
- A tree-only entry no longer present on disk in any form - recursed
  against an empty real directory listing, so every entry it used to
  contain gets its own `STATUS_DELETED <path>` line. Existence for a
  tree-typed entry is checked with a real `FilesFind`-based directory
  probe, not just the flat command's own `FileRead`-succeeds check
  (which only ever meant something for plain files before ADR 0010).
- A same-name entry that changes kind (file<->directory) - a new,
  honest `STATUS_TYPE_CHANGED <path>` signal, matching `Diff.HC`'s own
  choice, not silently mis-reported or guessed at.
- Rename detection (exact-hash, then fuzzy) stays scoped to one
  directory level at a time and blob-only, exactly like `Diff.HC`'s -
  cross-directory rename detection remains ADR 0010's own deliberately
  deferred item.

## Verified (real QEMU run, not fabricated)

A real 1-level-deep repo (`top.txt`, `SubA/inner.txt`) offered via
`hgit offertree`, then real working-directory changes made WITHOUT
offering them (`inner.txt` edited, a brand-new `SubA/SubB/deep.txt`
created two levels deep, `top.txt` deleted):

```
STATUS_NEW SubA/SubB/deep.txt
STATUS_MODIFIED SubA/inner.txt
STATUS_DELETED top.txt
STATUS_END
```

All three correctly classified and path-prefixed, at two different
real nesting depths, purely from comparing a live directory tree
against a committed one - not synthetic data. After actually offering
that same state via `hgit offertree`, a second `statustree` call
reports a clean tree (`STATUS_END` only, nothing outstanding) -
confirming the comparison is real and current, not stale.

**Regression**: `experiments/65-head-deletion/test_driver.hc` (the
project's full command-surface test, including the flat, non-recursive
`hgit status`) re-run clean immediately after - `STATUS_UNCHANGED
P65FileA.txt` unaffected, confirming zero interference with the
existing flat `status` path.

No HolyC compile-time gotchas hit this time (`COMPILE_OK` on first
push for both `Status.HC` and `Hgit.HC`) - the sibling-block-local-name
lesson from probe 94 was applied proactively while writing this one
(every recursive branch's own locals suffixed `_a`/`_b`/`_c` from the
start).

## Not yet done

- ~~The tree-only-entry "no longer present on disk in any form" branch
  wasn't directly exercised with a genuinely vanished subdirectory~~
  **Closed** (probe 103, `experiments/103-statustree-nested-directory-gone/`):
  using probe 101's own verified real directory-delete primitive,
  `SubA` was genuinely removed from disk (not just emptied); a real
  `hgit statustree` correctly reported both nested files as
  `STATUS_DELETED SubA/x.txt`/`SubA/y.txt`.
- Cross-directory rename/move detection (ADR 0010's own deferred
  scope, unchanged).
- `STATUS_TYPE_CHANGED` doesn't recurse into either side - same,
  deliberate limitation `Diff.HC`'s own version has.
- With `See.HC`/`Diff.HC`/`Status.HC` all now nested-tree-aware,
  `HistoryDoc.HC`/`ReconcileDoc.HC`/`Graph.HC` were re-confirmed (probe
  94's own write-up) to not need this work at all - they render commit
  chains/relations/branches, never a file listing. ADR 0010's own
  "rendering-command awareness of nested trees" item is now fully
  closed.
