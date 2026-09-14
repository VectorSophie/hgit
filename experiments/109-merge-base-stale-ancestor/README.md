# Probe 109 — `FindMergeBase`'s parent[0]-only walk: a real, confirmed correctness bug, found and fixed

Status: **PASS**. ADR 0011 and `MergeBase.HC`'s own original comment
both documented "genuine criss-cross histories... no evidence yet
hgit's own real usage needs" a stronger algorithm than a parent[0]-only
chain walk. This probe went looking for that evidence directly - not a
synthetic worry, a real, minimal, deliberately-constructed reproduction
- and found the limitation is worse than documented: it isn't just
ambiguous in a rare criss-cross case, it's flatly WRONG the moment
either side's history passes through **any** real merge commit at all.

## The real bug

`FindMergeBase` walked each commit's own `parent[0]` chain only. A real
merge commit's SECOND parent ("theirs" at merge time) is therefore
completely invisible to any later merge-base search - if the true
lowest common ancestor is only reachable through that second parent,
the old code silently falls back to a much older, stale ancestor
instead.

**Real, minimal reproduction** (`test_driver.hc`,
`P109MergeBaseStaleTest`): `main` and `Y` fork from a root commit,
diverge, and are merged (`M1`, a real 2-parent commit). A third path
`Z` forks from `Y`'s own PRE-merge commit (not from `M1`) and edits
the same file `Y` originally introduced. `main` advances again after
the merge. Merging `Z` back into `main`:

- The TRUE lowest common ancestor is `Y`'s own pre-merge commit - a
  real ancestor of `main`'s current head via `M1`'s second parent -
  under which the file is unchanged on `main`'s side since the merge
  and only changed by `Z`, a clean, non-conflicting resolution.
- The OLD `FindMergeBase` returned the much older root commit instead
  (parent[0] from `M1` only ever reaches `main`'s own pre-merge side).
  Under that stale base, the file looks "absent in base, added
  differently on both sides" - a real, **wrong** `MERGE_CONFLICT`,
  confirmed live: `MERGE_CONFLICT P109Y.txt` / `MERGE_ABORTED
  conflicts=1` (see `serial-log-evidence.txt`'s "BEFORE FIX" section).

Building this reproduction also surfaced a real, previously-
undocumented fact about `hgit offer`'s own semantics: a narrow,
single-file `find_mask` doesn't just leave OTHER tracked files alone,
it silently DROPS them from the new commit's tree entirely (no
old-tree carry-forward for unmatched names) - the test driver's own
comments document this, and every offer in it uses one consistent
wildcard mask instead, restoring/deleting files explicitly between
path switches (same discipline `experiments/99-hgit-merge/` already
established, since hgit has no working-directory checkout).

## The fix

`MergeBase.HC` rewritten: `CollectAllAncestors` does a real BFS over
**every** parent edge (not just index 0) from one commit, producing
its complete ancestor set. `FindMergeBase` then does a real BFS from
the other commit, level by level, over all of ITS parents too,
returning the first node found in the first commit's ancestor set -
the closest (breadth-first) common ancestor, correctly reaching a
merge's non-"ours" parent this time. Two small reusable "hash set"
helpers (`HashSetContains`/`HashSetAdd`, linear-scan, same style as
`Status.HC`'s own `new_matched`/`del_matched` arrays) back both BFS
passes, `MAlloc`'d from `idx_count` - the same real upper bound (total
distinct objects in the repo) every other dynamic buffer in this
codebase already uses.

**This is a real improvement, not a complete fix for every case.**
Genuine criss-cross ambiguity - multiple, equally-valid lowest common
ancestors with no single correct answer, needing something like Git's
own "recursive"/virtual-merge-base strategy - remains a real, separate,
deliberately out-of-scope limitation, unrelated to what this probe
fixes. What's fixed is narrower and more fundamental: the old code
didn't just handle ambiguity poorly, it ignored real, unambiguous
ancestry that was reachable all along.

## Verified

Same scenario, same real repo, before and after the fix
(`serial-log-evidence.txt`): before, `MERGE_CONFLICT P109Y.txt` /
`MERGE_ABORTED`; after, `MERGE_OK`, with the merged tree's own `see`
output showing all 4 real entries present. Confirmed the result is
SEMANTICALLY correct, not just conflict-free: `hgit diff` against the
merge commit's own first parent reports `DIFF_MODIFIED P109Y.txt` -
the file's content really did change to Z's edit, not silently stay at
`main`'s old value.

`tools/lint-package.sh` caught a real HolyC quirk before this ever
reached QEMU: a loop variable named `pi` collides with TempleOS's own
reserved `pi` constant (this project's own previously-documented
quirk, from `docs/research/01-templeos-holyc.md`) - renamed to `pidx`,
confirmed clean on the next lint pass. Full command-surface suite
(`tests/full-regression.hc`, including its own existing merge and
fast-forward-merge cases) and the standing regression both re-run
clean after the fix.

## What this does not do

- Does not solve genuine criss-cross ambiguity (see above) - a real,
  separate, still-undecided design question.
- No change to `hgit merge`'s own conflict-abort behavior (ADR 0011's
  own central decision) - a real conflict, once correctly identified as
  one, still aborts the whole merge with zero side effects, unchanged.
- No generation-number or commit-depth bookkeeping added - the BFS
  finds the closest common ancestor by breadth-first distance from one
  side only, a real, practical, but not perfectly symmetric heuristic.
