# Probe 98 — `FindMergeBase`: the merge-base primitive

Status: **PASS.** The next real, standalone piece a real `hgit merge`
command needs, following probe 97's own real prerequisite check
(hgit's object model already supports multi-parent commits with zero
code changes) - same "primitive first, then a real CLI decision"
pattern ADR 0010's own probes 90/91 established for subdirectory
support.

## What was built

`FindMergeBase` (`src/hgit-core/MergeBase.HC`, new file): given two
commit hashes, walks each one's own `parent[0]` chain backward - the
same single-parent-chain-following convention `History.HC`/
`HistoryDoc.HC`/`Graph.HC`'s own fork-point search already use and
honestly document as their own real, existing limitation. Chain A's
full ancestor set is collected first (`MAlloc`'d from the repo's own
real object count, no guessed cap); chain B is then walked backward
from its own tip, and the first commit found in chain A's set is the
lowest common ancestor.

**Deliberately scoped, matching this project's own ADR 0010-style
narrowing**: correct for the real, common case this project's own
history shape actually produces - a path forks once, directly, from
another path's own chain (`Paths.HC`'s `PathNew` copies the current
path's HEAD at creation time, so a real, findable single fork point
always exists). NOT attempted: real criss-cross histories with
multiple independent forks/merges producing ambiguous multiple lowest
common ancestors (Git's own "recursive" strategy territory) - no
evidence yet hgit's real usage needs that complexity.

Hit the same "duplicate member" sibling-block collision documented
since probe 5 (recurring again, as it did in probe 94) on first push -
`off_rel`/`off`/`content`/`pcount`/`parent`, each declared in BOTH
sibling `while` loops (chain A's walk, chain B's walk) within the same
function. Fixed by suffixing chain B's own locals `_b` throughout,
same fix pattern as probe 94.

## Verified (real QEMU run, not fabricated)

A real, asymmetric fork: root commit, `feature` path forked and
advanced ONE commit, `main` advanced TWO commits past the same fork
point. `FindMergeBase(main_head, feature_head)`:

```
P98_MERGEBASE_FOUND=1
P98_MATCHES_ROOT=1
```

The found base's own hex matches the real root commit's hash exactly,
byte for byte - correct despite the asymmetric commit counts on each
side (a naive "shorter chain wins" heuristic would get this wrong;
this doesn't use one).

The trivial case - a commit's own merge-base with itself - also
verified:

```
P98_SELF_FOUND=1
P98_SELF_MATCHES=1
```

**Regression**: `experiments/65-head-deletion/test_driver.hc` re-run
clean immediately after.

## Not yet done

- Real criss-cross histories (multiple candidate lowest common
  ancestors) - deliberately out of scope, no evidence of need.
- The actual three-way TREE merge (this probe only finds the base
  commit, not what to do with its tree vs the two diverged trees) -
  real, separate, substantial work, not attempted here.
- No real `hgit merge` command exists yet - `FindMergeBase` is a
  standalone primitive, not wired into any dispatch command, matching
  ADR 0010's own probe-90-before-probe-91 precedent.
