# Probe 72 — `hgit check` gains dangling/unreachable object detection

Status: **PASS** — closes the gap `Check.HC`'s own header comment
flagged since probe 69: "skips the dangling/unreachable categories,
which need a real reachability-from-HEAD walk this project hasn't
built."

## What was built

- `Index.HC` gains `IndexLookupPos` - the same linear hash scan
  `IndexLookup` already does, but returning the array position
  (0..count-1) instead of the byte offset, for a caller that needs to
  mark a parallel per-object flag array.
- `Meta.HC` gains `MetaPathCount`/`MetaPathListInto` - real-count and
  fill-a-buffer variants of the existing `MetaPathList` (which only
  ever printed), so a caller can enumerate every declared path's name
  ("main" plus every `MetaPathDeclare`'d one) without a fixed cap.
- `Check.HC` gains `CheckMarkReachable`: given a hash, marks its object
  reachable and recurses into everything it references (a commit's
  tree/parents/relation-target; a tree's own blob children). `HgitCheck`
  walks every declared path's HEAD through this, then reports every
  object left unmarked as `CHECK_DANGLING <kind> <hash>` -
  `CHECK_DANGLING_NONE`/`CHECK_DANGLING_COUNT <n>` at the end.

This is a real reachability model, not a heuristic: it follows the
actual stored object-graph edges (the same edges the referential-
integrity pass above it already resolves), from every real ref this
project has (every path's HEAD - there's no separate tag/branch
concept yet), exactly analogous to what real `git fsck` calls
"dangling"/"unreachable".

## Verified

`test_driver.hc` (`P72CheckDanglingTest`): offers one file (commit1, 0
parents), checks - `CHECK_DANGLING_NONE`. Offers a second, different
version of the same file (commit2, parent=commit1) - still
`CHECK_DANGLING_NONE` (both commits are on `main`'s own history).
Then `undo`s back to commit1 - **hgit's whole point is non-destructive
history, so `undo` moves HEAD back without deleting commit2's own
objects** - and checks again: `CHECK_DANGLING commit <hash>` /
`CHECK_DANGLING tree <hash>` / `CHECK_DANGLING blob <hash>`, exactly
the three objects unique to the undone commit,
`CHECK_DANGLING_COUNT 3`. This is a real, naturally-occurring dangling
case (produced by hgit's own actual undo/redo feature), not a
hand-corrupted fixture - the same relationship real Git has between
`git reset`/`git fsck`'s own dangling-commit reports and its reflog.

**Regression**: re-ran `experiments/65-head-deletion/test_driver.hc`
(the project's standing full command-surface regression) - all
commands still correct, and its own `check` step (against a real,
long-lived, `undo`/`redo`-history-bearing repo) now reports
`CHECK_DANGLING_NONE` too (see "Real bugs found" below for why this
number matters).

`tools/lint-package.sh` clean before every push (only the 3 known
built-in-manifest gaps).

## Real bugs found while building and testing this

Both logged in full in `docs/research/failed-approaches.md`'s
2026-09-13 entry:

1. **A real correctness bug in the check itself**, found only by
   testing against `P65Repo.hgs` - a long-lived repo this project has
   reoffered the same two file contents into across many probes.
   `Object.HC`'s own `ObjectPut` never deduplicates identical content,
   so the same hash can occupy multiple archive positions; the first
   version of `CheckMarkReachable`'s `IndexLookupPos`-based marking
   only ever proved reachability for whichever position it found
   first, falsely reporting every other duplicate as dangling (16 of
   36 objects on `P65Repo.hgs` - an implausible fraction that prompted
   a closer look rather than being accepted). Fixed with one linear
   coalescing pass: any position sharing a hash with an
   already-reachable position is content-identical and therefore
   reachable too. Re-verified: `P65Repo.hgs` now reports
   `CHECK_DANGLING_NONE`, and `P72Repo.hgs`'s own dedicated dangling
   test still correctly reports exactly 3 (the genuinely undone
   commit's own unique objects, none of them duplicates).
2. **A real bug in the test driver, not the feature**: deleting only
   `<repo>.hgs` before re-`init`-ing left `Meta.HC`'s own sidecar
   (`<repo>.hgs.m`) behind, producing a repo with a fresh empty object
   store but a stale `HEAD` pointing at a hash from the previous test
   run - a real `CHECK_BROKEN_REF commit_parent_missing` from the very
   first commit. Fixed by deleting both files. Left as a standing,
   undecided minor gap: `hgit init` itself doesn't detect or refuse
   this specific combination.

## Not yet done

- Only the object-graph model of reachability is implemented - there's
  no tag/branch-like ref beyond a path's own HEAD, so "reachable" here
  means exactly "reachable from some path's current HEAD," matching
  this project's own simpler ref model (see `docs/research/05-git-internals-and-product-practice.md`).
- No command to actually *reclaim* a dangling object's storage (real
  Git's own `git gc`/`git prune` equivalent) - `hgit check` only
  reports, consistent with this project's non-destructive-history
  design; deliberately not attempted here.
- The coalescing pass is `O(idx_count^2)` in the worst case (a linear
  scan per not-yet-reachable position) - fine at this project's own
  established "no premature optimization" scale, same stance as every
  other linear scan already in `Index.HC`.
