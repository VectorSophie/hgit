# Probe 102 — `hgit diff`'s "whole subdirectory vanished from disk" branch, directly exercised for real

Status: **PASS.** Closes the real, honestly-flagged gap probe 94's own
README left open: the not-found-by-name DELETED-recursion branch in
`Diff.HC`'s `DiffPrintTreeChanges` was only ever exercised indirectly
(an emptied-but-still-present directory), because this project had no
real "delete a directory from disk" primitive until probe 101. It does
now, so this probe uses it directly.

## What this probe does differently from probe 94

Probe 94 deleted every real file inside `SubA` individually but left
the (now-empty) directory entry itself on disk - `TreeBuildRecursive`
correctly still saw `SubA` as a real, empty subdirectory, so the
resulting diff went through the "found by name, hash differs, recurse"
branch, not the "not found by name at all" branch. This probe goes one
step further: after emptying `SubA`, it calls
`Del("C:/Home/P102Root/SubA", FALSE, TRUE, FALSE)` (probe 101's own
verified primitive) to remove the directory entry itself too, so the
second `offertree`'s own real, live directory listing genuinely has no
`SubA` at all - the true "wholly vanished directory" case.

## Verified (real QEMU run, not fabricated)

A real 1-level-deep repo (`top.txt`, `SubA/x.txt`, `SubA/y.txt`)
offered via `hgit offertree`, then `SubA` genuinely removed from disk
entirely (files individually, then the directory itself):

```
P102_SUBA_DEL_RESULT=0
P102_SUBA_GONE=1
```

`P102_SUBA_GONE=1` confirms `SubA` is truly absent (`FilesFind` finds
nothing), not just empty. A second `offertree`, then `hgit diff`
against the first commit:

```
DIFF_DELETED SubA/x.txt
DIFF_DELETED SubA/y.txt
DIFF_END
```

Both nested files correctly reported deleted, with their real full
paths, via the genuine not-found-by-name recursion branch this time -
`SubA` itself never appears as a tree entry in the second commit at
all, so `DiffPrintTreeChanges` recurses against a real empty tree for
it, exactly as `Diff.HC`'s own header comment always claimed it would.

A real cross-check immediately after: `statustree` on the
now-committed clean state reports nothing outstanding (`STATUS_END`
only), and `hgit check` passes (`CHECK_OK objects=9`,
`CHECK_REFS_OK`, `CHECK_DANGLING_NONE`).

**Regression**: `experiments/65-head-deletion/test_driver.hc` re-run
clean immediately after.

## Not yet done

- The same direct exercise for `Status.HC`'s own `StatusTreeWalk`
  (comparing a live directory against a committed tree, rather than
  two committed trees) - this probe only directly tests `Diff.HC`'s
  own version of the branch; `StatusTreeWalk`'s own equivalent
  (tree-only entry no longer present on disk in any form) uses the
  same real `FilesFind`-based directory probe already, but hasn't been
  exercised with a GENUINELY vanished (not just emptied) directory
  either, until now indirectly confirmed clean by this probe's own
  post-commit `statustree` check reporting nothing outstanding.
