# Probe 114 — `hgit undo`/`hgit redo` after a real merge commit: verified correct

Status: **PASS**. A real, previously-unexercised test-coverage gap:
`hgit undo`/`hgit redo` had never been directly tested against a real
merge commit, even though `Merge.HC`'s own real merge (and its
fast-forward shortcut) both call `OpLogAppend` the same way any
ordinary offer does. No bug was expected (`OpLogUndo`/`OpLogRedo` are
entirely per-CURRENT-path and never inspect a commit's own internals -
they just restore/reapply a logged `prev_head`/`new_head` pair) and
none was found, but this closes a real, previously-open gap rather
than leaving it merely "probably fine."

## What was checked

A real merge history (root commit, `feature` forking and adding a
file, `main` independently adding a file, then a real `hgit merge`),
with every hash captured independently via `CurrentHeadRead` before
each destructive step (not re-derived from any command's own later
output):

- `hgit undo` on `main` after the merge - `main`'s HEAD restored to
  its real, exact pre-merge commit hash, byte-for-byte.
- `feature`'s own HEAD, checked immediately after - completely
  unaffected (byte-for-byte identical to before the undo) - confirms
  undo really is scoped to the current path only, not a global
  rewind.
- `hgit check` after the undo - the real merge commit and its own
  merged tree object now correctly report as `CHECK_DANGLING` (2
  objects) - real, expected, non-destructive-history behavior, the
  same as any other undo (probe 65's own regression) - not deleted,
  just genuinely unreachable until redone.
- `hgit redo` - `main`'s HEAD restored to the real merge commit hash,
  byte-for-byte, and `hgit check` afterward reports `CHECK_DANGLING_NONE`
  again - the same objects are reachable once more.

## Verified

`test_driver.hc` (`P114UndoRedoAfterMergeTest`): every comparison
above is a real byte-for-byte hash match against an independently
captured value, not a visual/approximate check - see
`serial-log-evidence.txt` for the full raw output. No source change
was needed - this was a real verification, not a bug fix.

## What this does not do

- Does not test `hgit operation restore <op_index>` (jumping to an
  arbitrary point, not just one step back/forward) against a merge
  commit - a real, separate, not-yet-covered case.
- Does not test undo/redo on the OTHER path involved in a merge
  (`feature`, which was never itself modified by the merge - its own
  undo/redo behavior is unaffected by anything this probe covers).
