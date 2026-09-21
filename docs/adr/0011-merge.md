# ADR 0011 — `hgit merge`: scope for a first real slice

> **Update (v1.8.3-v1.8.5):** the "any conflict aborts everything with zero side effects" behavior described below was superseded in part by ADR 0016 (conflicts now persist and are resolvable) and ADR 0017 (rename-aware). The text below is the original decision record and is left as written.

## Status

**Implemented (first slice).** This ADR exists because probes 97 and
98 established real evidence for the first time (the object model
already supports a real multi-parent commit with zero code changes;
a real, standalone `FindMergeBase` primitive works correctly against a
real, asymmetric fork) - per this project's own standing discipline,
no ADR gets written before its supporting evidence exists, and this is
that evidence. Probe 99 then made the real CLI-semantics and
conflict-handling decisions this ADR documents, and wired everything
into a real command: `hgit merge <repo> <other_path_name>`. Probe 100
then closed the "flat trees only" limitation Decision point 2 first
described - `MergeTreesRecursive` now applies the identical
base/ours/theirs decision one directory level deeper wherever every
side agrees a name is a real subdirectory, not a special case.

## Context

hgit's named paths (`Paths.HC`, ADR-less since it predates this
project's own ADR discipline) can diverge (`path new`/`path go`) but,
until this ADR's own probes, had no way to rejoin. Every real VCS this
project has researched (`docs/research/04-vcs-comparison.md`,
`05-git-internals-and-product-practice.md`) treats bringing diverged
history back together as a first-class operation - this was a real,
practical gap, not a cosmetic one, and doc 05's own "Not yet done" list
had flagged "merge-base/three-way merge" since this project's earliest
research pass.

Probe 97 confirmed the missing prerequisite wasn't actually missing:
`Commit.HC`'s own `CommitEncode`/`CommitParentHash` were never
hardcoded to one parent, and `Check.HC`'s reachability/referential-
integrity passes already loop over every real parent generically - a
manually-injected real 2-parent commit round-tripped correctly with
**zero code changes** anywhere. Probe 98 built and verified
`FindMergeBase`, a real, standalone primitive finding the lowest
common ancestor of two commits by walking their own `parent[0]` chains
backward (the same convention `History.HC`/`HistoryDoc.HC`/`Graph.HC`
already use).

What was left is a genuine design question this ADR settles: how much
of "real merge support" to build in one first slice, and - the harder
question every real VCS answers differently - what to do when a real
conflict is found, given hgit has no working-directory checkout step
and no existing conflict representation of any kind.

## Decision

**First slice, scoped narrowly, matching this project's own
established incremental-ADR pattern (ADR 0010's own precedent):**

1. **A real merge-base search and a real three-way tree merge**
   (probe 99, `Merge.HC`'s `HgitMerge`) - given the current path's own
   HEAD (`ours`) and another declared path's HEAD (`theirs`), finds
   their real merge base (probe 98's `FindMergeBase`), then applies
   the same base/ours/theirs decision every real three-way merge uses
   (`docs/research/05-git-internals-and-product-practice.md`):
   unchanged-from-base on one side takes the other side's value;
   changed differently on both sides is a real conflict.
2. **Flat trees only at first, then recursed once verified standalone
   (probe 100).** Any entry name where the sides that have it at all
   DISAGREE on whether it's a real `OBJ_TREE` (a genuine kind mismatch
   - a file on one side, a directory on another) is still treated as
   an honest conflict, not silently skipped or guessed at. Where every
   present side agrees it's a real subdirectory, `MergeTreesRecursive`
   now recurses into it, reusing the exact same base/ours/theirs
   decision one level deeper - matching how `Diff.HC`/`Status.HC` were
   themselves built flat first before recursion was added later (ADR
   0010's own probes 93-95), then actually extended here once the flat
   case was independently verified solid.
3. **No conflict resolution mechanism of any kind.** A real conflict
   - of any kind: both sides edited the same name differently, one
   side deleted while the other edited, a nested-tree name, or a
   same-name kind change - aborts the ENTIRE merge with zero side
   effects: no commit is created, no HEAD moves, nothing is written to
   the archive. This is the single most consequential decision this
   ADR makes, and the one most likely to be revisited (see "What would
   justify revisiting this"): hgit has no working-directory checkout
   step the way Git does, so there is no natural place to write
   `<<<<<<<`/`=======`/`>>>>>>>` conflict markers into a file the way
   Git's own three-way merge does - inventing a conflict
   representation (a new object type? a blob whose own content embeds
   markers? something else?) with no real evidence yet of which shape
   a real hgit workflow actually needs is exactly the kind of premature
   design this project's own standing discipline argues against.
   A clean, honest, total abort - the same non-destructive stance
   every other real hgit command already takes - is the real, minimal,
   defensible choice until real usage says otherwise.
4. **Trivial cases handled without a merge commit** - fast-forward
   (`ours == base`, the current path just adopts `theirs`'s own HEAD
   directly) and already-up-to-date (`theirs == base`, nothing to do)
   - matching every real VCS's own standard behavior, not a novel
   design choice.

## Alternatives considered

- **Invent a real conflict-marker/resolution mechanism in this same
  slice** (e.g., a new object type storing base/ours/theirs hashes for
  later resolution, or embedding literal marker text into a blob):
  rejected for this slice - a real, substantial design question with
  no existing evidence for which shape hgit's own real usage would
  need, and this project's own standing discipline (ADR 0007's own
  "no guessed cap" lesson, generalized) argues against designing a
  feature ahead of real evidence it's needed in a specific shape.
- **Recurse into nested trees immediately, since `Diff.HC` already has
  the pattern**: rejected for this slice - would meaningfully grow the
  size and risk of an already-substantial single change, and the flat
  case is independently valuable and testable on its own, matching
  ADR 0010's own reasoning for shipping `TreeBuildRecursive` before
  wiring it into any command.
- **Silently skip nested-tree entries instead of reporting them as
  conflicts**: rejected - a silent skip is a silent, wrong merge (the
  resulting tree would be missing real content neither side actually
  deleted), which is worse than a clean, honest refusal. Reporting it
  as a conflict keeps the same "abort with zero side effects on
  anything unexpected" invariant the rest of this slice already
  relies on.

## What this slice does not do

- ~~Merge nested trees (subdirectories)~~ **Closed** (probe 100,
  `experiments/100-merge-nested-trees/`): `MergeTreesRecursive` applies
  the exact same base/ours/theirs decision one directory level deeper
  whenever every side that has a given name at all agrees it's a real
  `OBJ_TREE` - not a special case, the identical per-name logic Decision
  point 1 already describes, just applied recursively. A same-name
  kind mismatch (tree on one side, file on another) is still a real,
  honest conflict. Verified: a non-conflicting merge inside a shared
  subdirectory (both sides' own nested edits survive into a real,
  newly-computed nested tree object) and a real conflict inside a
  shared subdirectory (`MERGE_CONFLICT SubB/z.txt`, the whole merge
  aborting with zero side effects, same as the flat case).
- Resolve any real conflict, at any depth - the whole merge aborts
  instead (see Decision point 3). No `resolve`/`continue` command, no
  conflict-marker format, no partial commit.
- Handle real criss-cross histories with ambiguous multiple lowest
  common ancestors - `FindMergeBase`'s own already-documented
  limitation (probe 98), still real and unchanged. **A related but
  DIFFERENT limitation was found and fixed since** (probe 109,
  `experiments/109-merge-base-stale-ancestor/`): the original
  parent[0]-only chain walk wasn't just ambiguous in a rare criss-cross
  case, it was flatly WRONG the moment either side's history passed
  through any real merge commit at all - a merge's own second parent
  was invisible to it, causing a real, confirmed, reproduced false
  `MERGE_CONFLICT` where a clean merge should have happened.
  `MergeBase.HC` now does a real ancestor-set BFS over every parent
  (not just index 0) from both sides. Genuine multi-LCA criss-cross
  ambiguity remains exactly as real and unaddressed as this bullet
  already said - this fix only stops ignoring real, unambiguous
  ancestry that was reachable all along.
- Merge rename information across the two sides (e.g., recognizing
  that `theirs` renamed a file `ours` also edited under its old name)
  - each side's own tree is compared purely by entry NAME, the same
  scope ADR 0009's own rename detection has for `status`/`diff`
  independently, not combined here.
- ~~Carry file mode (ADR 0015) through a merge~~ **Closed** (probe
  121, `experiments/121-merge-mode-3way/`, the removed v1.8 roadmap's own
  "mode-only changes" gap): mode is now a wholly separate 3-way
  decision from content inside `MergeTreesRecursive` - a file's bytes
  and its mode can each change independently, each surviving entity's
  mode resolved base/ours/theirs the same way content already is, and
  a genuine mode-only conflict (both sides changed mode, differently)
  is reported and aborts the whole merge exactly like a content
  conflict, not silently guessed. Verified: a clean mode-only round
  trip (`DIFF_MODE_CHANGED file.txt 0 -> 2` on the resulting merge
  commit) and a genuine mode-only conflict (`MERGE_CONFLICT`, zero side
  effects, same as any other real conflict). One real, honest, narrower
  limitation remains: a mode-only change on the side a file gets
  DELETED from isn't itself detected as a conflict, since the existing
  edit-vs-delete decision only ever consults content - not attempted
  here.

## What would justify revisiting this

- Real usage where a genuine conflict is common enough that a total
  abort is a real practical burden - the strongest, most likely
  trigger for designing a real conflict-resolution mechanism. If that
  happens, `docs/research/04-vcs-comparison.md`'s own Pijul section
  names a real, concrete alternative shape worth considering then -
  representing an unresolved conflict as real, recoverable, inspectable
  repository state (Pijul's own approach) rather than only Git's
  file-level conflict-marker model - not designed further here. The
  same doc's own Darcs section adds a real, cautionary data point for
  that path specifically: Darcs' own documented "conflict fight"
  (exponential-time conflict resolution as conflict count grows) is a
  genuine performance pathology this project should check any future
  design against, not just assume away by analogy to Pijul's own fix.
- Real usage of criss-cross path histories (a path forking from a
  path that itself forked from `main`, then merging in an order that
  produces genuine ambiguity) - not yet observed in any real workflow
  this project has built. (Probe 109 confirms the underlying algorithm
  is now at least a real, all-parents ancestor-set BFS rather than a
  parent[0]-only chain, so this remaining gap is specifically about
  multi-LCA ambiguity, not about ignoring reachable ancestry.)
