# Probe 100 — `hgit merge` recurses into nested trees

Status: **PASS** (with one real bug found and fixed while verifying
it - see below). Closes ADR 0011's own first documented follow-up:
nested-tree three-way merging, previously reported as an honest,
aborting conflict rather than attempted.

## What was built

`MergeTreesRecursive` (`Merge.HC`): the flat, per-name three-way
decision probe 99 already had, made recursive - the same generic-per-
object-type pattern this project already established (`Check.HC`'s
`CheckMarkReachable`, `See.HC`'s `SeePrintTreeEntries`, `Diff.HC`'s
`DiffPrintTreeChanges`, `Status.HC`'s `StatusTreeWalk`). A name where
every side that has it at all agrees it's a real `OBJ_TREE` recurses
into a three-way merge of that subtree one level deeper, reusing the
exact same base/ours/theirs logic - not a special case. A name that's
a tree on one side and a plain file on another (a genuine kind
mismatch) is still a real, honest conflict, not guessed at.

A real, honestly-documented trade-off from recursing (see `Merge.HC`'s
own header comment): `archive`/`alen` are now allocated up front,
before the merge decision is known, so successful nested subtrees can
be `ObjectPut` as recursion unwinds. This is still fully consistent
with ADR 0011's own "no side effects on conflict" stance - nothing is
ever written to the real repo FILE unless the whole merge succeeds,
the in-memory scratch buffer is simply discarded (`Free`'d, never
`FileWrite`'d) on any abort - just no longer true that literally zero
bytes are ever computed in memory before an abort is detected, worth
naming honestly rather than silently relying on the stronger claim.

## A real bug found and fixed by this probe's own test

The first real run of the nested-conflict case (both sides editing
the same nested file differently) reported `MERGE_CONFLICT SubB/`
instead of the real, expected `MERGE_CONFLICT SubB/z.txt` - the
conflict name was silently truncated to just the path PREFIX. Root
cause: two places in `MergeTreesRecursive` copied `full_name` (the
real prefix-plus-name string) into the conflict buffer using `cap =
name_len` - the LOCAL entry name's own length (e.g. `StrLen("z.txt")
== 5`), not `full_name`'s real, full length (`StrLen("SubB/z.txt") ==
10`). At the top level (empty prefix) `full_name == name` so this bug
was invisible in every one of probe 99's own flat-only tests; only a
real, genuinely nested conflict exposed it. Fixed by using the real,
already-tracked `full_name` length (`fi`, the running index the
prefix-then-name copy loop already left pointing past the last real
character) instead of `name_len` in both places. Re-verified after the
fix: `MERGE_CONFLICT SubB/z.txt`, correct.

## Verified (real QEMU runs, not fabricated)

**A real, non-conflicting merge INSIDE a shared subdirectory** -
`main` edited one nested file, `feature` edited a different nested
file in the SAME subdirectory:

```
MERGE_OK
SEE_TREE entries=2
  entry type=2 id=230257349406945f name=SubA
    entry type=1 id=9d3ef29b33a0d879 name=x.txt
    entry type=1 id=a5d5719b129b1fc6 name=y.txt
  entry type=1 id=c26648ae47ad2403 name=top.txt
CHECK_OK objects=21, CHECK_REFS_OK, CHECK_DANGLING_NONE
```

Both nested files' own edits survived into a real, newly-computed
`SubA` tree object - `entry type=2` confirms a genuine nested
`OBJ_TREE`, not a flattened result.

**A real conflict INSIDE a shared subdirectory** - both sides edit the
SAME nested file differently:

```
MERGE_CONFLICT SubB/z.txt
MERGE_ABORTED conflicts=1
```

`P100_CASE2_HEAD_UNCHANGED=1` and `CHECK_OK objects=12` (unaffected) -
the same zero-side-effects guarantee probe 99 already verified for the
flat case, now confirmed at a nested depth too.

**Regression**: probe 99's own full four-case test re-run clean after
the fix (non-conflicting, conflict, fast-forward, already-up-to-date -
all still correct), plus `experiments/65-head-deletion/test_driver.hc`
(the project's full command-surface test).

## Not yet done

- Real criss-cross histories with ambiguous multiple merge bases -
  `FindMergeBase`'s own already-documented limitation, unchanged.
- Any real conflict resolution mechanism - a conflict at any depth
  still fully aborts the merge (ADR 0011's own central decision,
  unchanged by adding recursion).
