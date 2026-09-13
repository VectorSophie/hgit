# Probe 99 — `hgit merge`: a real, first-slice merge command

Status: **PASS.** The real command probes 97 (multi-parent commits
already supported) and 98 (`FindMergeBase`) were building toward -
`hgit merge <repo> <other_path_name>` brings another declared path's
history into the current one.

## What was built

`Merge.HC` (new file), `HgitMerge`:

1. Reads the current path's own HEAD (`ours`) and the named other
   path's HEAD (`theirs`, via `MetaReadHead`).
2. Finds their real merge base via probe 98's `FindMergeBase`.
3. **Trivial cases handled without a merge commit** (matching every
   real VCS's own standard behavior): `theirs == base` -> already up
   to date, nothing to do; `ours == base` -> a real fast-forward, the
   current path's HEAD just moves to `theirs_head` directly.
4. **The real three-way merge**, for the remaining case: resolves
   base/ours/theirs trees, collects the union of every real entry name
   across all three (`MergeCollectNames`), then for each name applies
   the same base/ours/theirs decision Git's own three-way merge uses
   (see `docs/research/05-git-internals-and-product-practice.md`):
   unchanged-from-base on one side takes the other side's value;
   changed differently on both sides is a real conflict.
5. **A real, honest first-slice scope limit**: any name where either
   side's own entry is an `OBJ_TREE` (a subdirectory) is treated as a
   conflict too, reported with the exact same `MERGE_CONFLICT <name>`
   tag as any other conflict (no distinct tag exists) - flat trees
   only in this slice, matching how `Diff.HC`/`Status.HC` were built
   flat before recursion was added later (probes 94/95).
6. **No conflict resolution exists yet.** Any real conflict of any
   kind aborts the WHOLE merge with zero side effects - no commit
   created, no HEAD moved - the same non-destructive stance every
   other real hgit command already takes. `MERGE_CONFLICT <name>` per
   conflicting entry, then `MERGE_ABORTED conflicts=<n>`.
7. On success: a real 2-parent commit (`ours_head`, `theirs_head`),
   the merged tree, `OpLogAppend`, `CurrentHeadWrite` - the same real
   object-model support probe 97 already verified.

Wired into `Hgit.HC` as `hgit merge <repo> <other_path_name>`.

**Two real HolyC gotchas hit and fixed before this compiled**:
- `continue` isn't a real keyword (documented since probe 5, this
  file's own header cites the exact `holyc-parser` bug-compat corpus
  entry) - caught by `tools/lint-package.sh` before ever reaching
  QEMU. Fixed by nesting the rest of each loop body inside an `else`/
  guarded `if` instead of an early skip, in three places.
- The recurring "duplicate member" sibling-block collision (probes
  94/98) - `ci`/`cap` each declared in multiple sibling `if` blocks
  under the same per-name loop. Fixed by declaring both once at the
  top of the loop and reusing them throughout, rather than suffixing
  every occurrence - a cleaner fix than probes 94/98 used, worth
  noting as the simpler option when the colliding blocks are already
  siblings under one shared loop (as opposed to genuinely parallel
  recursive calls, where distinct suffixes are still the right choice).

## Verified (real QEMU runs, not fabricated)

Four real, independent scenarios, all in one test:

**A real, non-conflicting merge** - `main` edited one file, `feature`
edited a different file, no overlap:
```
MERGE_OK
SEE_COMMIT ts=6107466 parents=2 msg=merge feature
SEE_TREE entries=2
  entry type=1 id=4bac51b0af161d8a name=P99A_fileA.txt
  entry type=1 id=ffe4beeb0f1c60cc name=P99A_fileB.txt
SEE_END
CHECK_OK objects=14, CHECK_REFS_OK, CHECK_DANGLING_NONE
```
Both files' own edits survived into the merged tree - `parents=2`
confirms the real multi-parent commit probe 97 already proved
possible is now produced by a real command, not a synthetic test.

A real test-design lesson surfaced building this case: `hgit offer`
replaces its ENTIRE tree with whatever `find_mask` matches (no
old-tree carry-forward for unmatched names - confirmed by re-reading
`Offer.HC` directly, not assumed), and switching paths (`path go`)
doesn't restore working-directory files to that path's own committed
state (hgit has no checkout step). The first draft of this test used
single-file `find_mask`s per offer, silently dropping the other file
from every subsequent commit - not a bug in `HgitMerge`, a real
mistake in the test's own real-world modeling of what "leave a file
unedited" actually requires here. Fixed: a single wildcard mask
covering both files every offer, and an explicit `FileWrite` restoring
the untouched file back to its real root content before the other
path's own offer (since the real, single working directory would
otherwise still hold the other path's own edit).

**A real conflict** - both `main` and `feature` edit the SAME file
differently:
```
MERGE_CONFLICT P99B_file.txt
MERGE_ABORTED conflicts=1
```
`P99_CASE2_HEAD_UNCHANGED=1` - the current path's own HEAD is
provably untouched; `CHECK_OK objects=9` - unaffected, confirming no
partial commit or dangling object was created by the aborted attempt.

**A real fast-forward** - `main` untouched since the fork, `feature`
advanced:
```
MERGE_FASTFORWARD
```
`P99_CASE3_FF_MATCHES=1` - `main`'s own HEAD now exactly equals
`feature`'s own HEAD, confirmed by direct hash comparison, not assumed
from the status line alone.

**Already up to date** - merging a path that's already an ancestor of
current:
```
MERGE_ALREADY_UP_TO_DATE
```

**Regression**: `experiments/65-head-deletion/test_driver.hc` (the
project's full command-surface test) re-run clean immediately after.

## Not yet done

- Nested-tree three-way merging (this slice is flat-only; any
  subdirectory involved aborts as an unsupported conflict).
- Any real conflict RESOLUTION mechanism - a conflict fully aborts
  today, with no partial commit, no conflict-marker blob format, no
  resolve command. A real, separate, substantial follow-up.
- Real criss-cross histories with ambiguous multiple merge bases -
  `FindMergeBase`'s own already-documented limitation, unchanged here.
