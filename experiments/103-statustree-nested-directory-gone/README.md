# Probe 103 — `hgit statustree`'s "whole subdirectory vanished from disk" branch, directly exercised for real

Status: **PASS.** Same real gap probe 102 closed for `Diff.HC`
(committed-tree vs. committed-tree), this time for `Status.HC`'s own
`StatusTreeWalk` (live directory vs. committed tree): a genuinely
vanished subdirectory (not just emptied) had never been directly
exercised, since this project had no real "delete a directory from
disk" primitive until probe 101.

## What was built

Nothing new in `Status.HC` itself - `StatusTreeWalk`'s own
tree-only-entry deletion pass already used a real `FilesFind`-based
directory probe (not the flat command's own `FileRead`-succeeds check)
since probe 95 was first built. This probe simply gives it the real
adversarial input it was designed for but had never actually seen: a
subdirectory the live directory listing has NO trace of at all.

## Verified (real QEMU run, not fabricated)

A real 1-level-deep repo (`top.txt`, `SubA/x.txt`, `SubA/y.txt`)
offered via `hgit offertree`, then `SubA` genuinely removed from disk
entirely (files individually, then the directory itself, probe 101's
own verified primitive) - deliberately left UNCOMMITTED this time, so
`hgit statustree` compares a live directory (with `SubA` truly gone)
against the still-committed tree (which still has both nested files):

```
P103_SUBA_GONE=1
STATUS_DELETED SubA/x.txt
STATUS_DELETED SubA/y.txt
STATUS_END
```

Both nested files correctly reported deleted, with their real full
paths, via the genuine "tree-only entry, no longer present on disk in
any form" branch - not the emptied-but-present case probe 95's own
original test used.

**Regression**: `experiments/65-head-deletion/test_driver.hc` re-run
clean immediately after.

## Not yet done

Cross-directory rename/move detection and `STATUS_TYPE_CHANGED`
recursion remain deliberately out of scope, unchanged from probe 95's
own README - this probe only closes the one specific
directly-untested branch.
