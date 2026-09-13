# Probe 97 — does hgit's object model already support real multi-parent (merge) commits?

Status: **PASS.** A real prerequisite check, same pattern ADR 0010's
own probes 88/89 used before subdirectory support was designed or
implemented: confirm the object model can already do the thing before
designing a command around it, rather than assuming.

## Why this probe

`docs/research/05-git-internals-and-product-practice.md`'s own "Not
yet done" list has flagged "merge-base/three-way merge" since this
project's earliest research pass - hgit currently has **no merge
command at all**: two named paths (`Paths.HC`) can diverge (`path
new`/`path go`) but there's no way to bring them back together. Before
designing an actual merge algorithm (finding a common ancestor,
three-way diffing trees, handling conflicts - a large, separate
feature), this probe checks the one real, cheap question first: does
`Commit.HC`'s own encoding, and every command that already walks a
commit's parents, already work correctly for `parent_count > 1`, even
though no real command has ever created one?

## What was found

**Yes, with zero code changes needed anywhere.** `Commit.HC`'s own
`CommitEncode` already takes a generic `parent_count`/`parent_hashes`
(a flat, concatenated array) - it was never hardcoded to one parent,
just never exercised past 1 by any real caller. `CommitParentHash(buf,
idx)` already indexes generically. `Check.HC`'s own
`CheckMarkReachable` (the reachability/dangling walk) and its
referential-integrity pass both already loop
`for (pidx=0; pidx<pcount; pidx++)` generically - not hardcoded to a
single parent either. `See.HC`'s `SEE_COMMIT` line already prints the
real `parents=%d` count it reads back.

This probe manually constructed a real, synthetic 2-parent commit -
**not** a real three-way merge (the commit's own tree is just reused
from one real parent, unchanged; this probe is scoped to the object
model question only, not the merge algorithm itself) - via the same
direct-archive-manipulation technique probe 92 used for its own
adversarial `Check.HC` test: two real, genuinely diverged commits
(`main`'s own HEAD after an edit, `feature`'s own HEAD after a
different edit from the same root), then a manually-encoded commit
with both as real parents, injected into the real archive and set as
`main`'s new HEAD.

Real result:
```
SEE_COMMIT ts=3980602 parents=2 msg=merge_test_two_parents
CHECK_OK objects=10
CHECK_REFS_OK
CHECK_DANGLING_NONE
```

`parents=2` printed correctly; `CHECK_REFS_OK` confirms the
referential-integrity pass validated BOTH parent references (not just
the first); `CHECK_DANGLING_NONE` confirms the recursive reachability
walk followed BOTH parent pointers to mark every object from both
diverged branches reachable - a real, deeper check than "it didn't
crash," since a dangling report would have surfaced a walk that only
followed one parent.

**Regression**: `experiments/65-head-deletion/test_driver.hc` re-run
clean immediately after.

## What this does NOT show (honestly scoped)

- **No real merge algorithm exists.** Finding a real merge base (the
  lowest common ancestor in the commit DAG - non-trivial once
  criss-cross histories are possible), and a real three-way tree merge
  (walking both diverged trees against their common ancestor's tree,
  auto-resolving non-overlapping changes, flagging real conflicts) are
  both real, separate, substantial work - not attempted here.
- `History.HC`/`HistoryDoc.HC` already, honestly, only ever follow
  `CommitParentHash(content, 0)` (documented in `History.HC`'s own
  header comment, not a new finding) - a merge commit's OTHER
  parent(s) wouldn't show in those two commands' own linear view. Not
  tested here since it wasn't touched; `hgit graph`'s own real
  branch-fork rendering is the closer analogue but wasn't run against
  a real merge commit either.
- No real command creates a multi-parent commit yet - this probe's own
  construction technique (manual `CommitEncode` + direct archive
  injection) is not something a real user-facing command does.

## Real next step, not attempted here

A real `hgit merge <repo> <path_name>` (or similar) command needs, at
minimum: (1) a real merge-base search (walk both paths' own parent
chains backward, same technique `Graph.HC`'s own fork-point search
already uses, extended to find the actual lowest common ancestor, not
assume one exists on `main`'s own chain the way `Graph.HC` currently
does), (2) a real three-way tree-level merge (reusing `Diff.HC`'s own
recursive tree-walking pattern, extended to three trees rather than
two, with a real, defined conflict representation - this project has
none yet), (3) a decision on whether/how a conflict blocks the commit
outright or gets recorded some other way. All real, separate,
well-scoped follow-up work for a future session, now that the one
cheap prerequisite question (does the object model already support the
result?) has a real, verified yes.
