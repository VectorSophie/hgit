# Probe 115 — `hgit operation restore` to a real merge commit: verified correct

Status: **PASS**. Closes the exact gap probe 114's own README flagged
as separate and not covered: `hgit operation restore <index>` had
never been tested against a real merge commit either.
`OpLogRestore` is structurally identical to `OpLogUndo`/`OpLogRedo`
(per-current-path, jumps HEAD directly to the logged `new_head` at a
given index, no inspection of a commit's own internals at all) - no
bug was expected, and none was found, but this closes the flagged gap
with a real, direct test rather than an inference from a sibling
function's own already-verified behavior.

## What was checked

A real merge history (root, `feature` forking and adding a file,
`main` independently adding a file, then a real `hgit merge`), then
one more real commit afterward (`main_commit_3`) so restoring to the
merge is a genuine jump backward, not a no-op.

`hgit operation history` confirms the real op index: `OP 2`'s own
`new=` field matches the merge commit's hash byte-for-byte (captured
independently via `CurrentHeadRead` right after the merge, not
re-derived from the operation log itself). `hgit operation restore
<repo> 2` then jumps HEAD directly to that same hash, confirmed
byte-for-byte again. `hgit check` afterward correctly reports
`main_commit_3`'s own unique blob/tree/commit (3 objects) as
`CHECK_DANGLING` - real, expected non-destructive-history behavior:
restoring past a commit doesn't delete anything, it just makes
whatever was only reachable through it genuinely unreachable, exactly
like `undo` already does (probe 114).

## Verified

`test_driver.hc` (`P115OperationRestoreToMergeTest`): every hash
comparison above is a real byte-for-byte match, not visual inspection
- see `serial-log-evidence.txt` for the full raw output, including the
real operation-log entries themselves. No source change was needed -
a real verification, not a bug fix.

## What this does not do

- Does not test restoring to an index BEFORE the merge from a point
  AFTER it (this probe only tests jumping directly TO the merge) - a
  real, separate case, structurally the same mechanism, not expected
  to differ but not directly exercised here.
- Does not test `operation restore` on the OTHER path involved in the
  merge (`feature`) - unaffected by anything this probe covers, same
  reasoning as probe 114's own equivalent note.
