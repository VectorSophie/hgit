# ADR 0010 — Subdirectory support: scope for a first real slice

## Status

**Decided, not yet implemented.** This ADR exists because probes 88
and 89 established real evidence for the first time (recursive
directory walking is buildable; nested `OBJ_TREE` objects round-trip
correctly through the existing object model, zero code changes) - per
this project's own standing discipline, no ADR gets written before its
supporting evidence exists, and this is that evidence.

## Context

hgit's entire object model has been flat/single-level since M0:
`Offer.HC` calls `FilesFind(find_mask, 0)`, a single non-recursive
scan, and builds one tree with no entries pointing at other trees,
even though `Tree.HC`'s own entry format has reserved a `child_type`
byte for `OBJ_TREE` since ADR 0001/0004. Real projects have
subdirectories; this is a real, practical gap, not a cosmetic one.

Probe 88 confirmed the missing primitive (`FilesFind` doesn't recurse,
but `CDirEntry.attr & 16` reliably distinguishes a directory from a
file, and a plain recursive walker built on both works). Probe 89
confirmed the object model itself already handles a nested tree entry
correctly with zero changes. Both real technical blockers are gone.

What's left is a genuine design question this ADR settles: how much of
the "real subdirectory support" feature to build in one first slice,
and how entity-ID/rename continuity (ADR 0004/0009) should behave once
files can move between directories, not just be renamed within one.

## Decision

**First slice, scoped narrowly, matching this project's own
established incremental-ADR pattern (ADR 0004 → 0009's own
by-name-then-exact-hash-then-fuzzy progression) - and narrower than
this ADR's own first draft turned out to need, once the real
implementation shape was worked through (see "Alternatives
considered"):**

1. **A real, standalone, tested recursive tree-building primitive**
   (probe 90) - a function that, given a real directory path and the
   matching old tree from a parent commit (if any), recursively walks
   real subdirectories (probe 88's technique), stores each real file as
   an `OBJ_BLOB` and each real subdirectory as a properly nested
   `OBJ_TREE` (depth-first - a tree's own hash can only be computed
   once its full content, including any nested subtrees, is known),
   and carries entity IDs forward by full relative path (extending ADR
   0004's by-name lookup to recurse into matching subdirectories,
   exact-content and fuzzy rename matching per ADR 0009 applied
   *within* each directory level, not yet across a directory move -
   see "What this slice does not do"). Verified against a real,
   on-disk nested directory structure, not just synthetic in-memory
   objects (probe 89's own scope) - this is the real gap probe 89
   deliberately left open.
2. **Not wired into `hgit offer`'s own live dispatch in this slice.**
   Making `hgit offer <repo> <find_mask> <message>` itself build
   nested trees is a real, separate CLI-semantics decision (does
   `find_mask` become recursive by default? does it need a distinct
   flag or command, given every real offer this project has ever made
   assumes flat, single-`find_mask`-directory semantics?) - deliberately
   not decided in this same slice as the primitive itself, to keep the
   already-substantial primitive independently reviewable and to avoid
   risking a regression in `Offer.HC`'s own live, heavily-relied-on
   entity-ID/rename logic before the recursive primitive is itself
   proven solid.
3. **`Check.HC` recursion is real, separate follow-up, not this
   slice.** Referential integrity ought to recurse into a nested
   tree's own children once real commands can produce one - a real
   correctness item to close before this feature is wired in for
   real, not before the primitive itself exists.

## Alternatives considered

- **Build the whole feature (real command wiring, every consuming
  command) in one slice**: rejected - too large a change to verify
  responsibly in one pass, and this project's own history (ADR
  0004/0007/0009, each shipped incrementally with explicit follow-up
  items) argues against it. This was this ADR's own original draft
  scope, revised narrower once the real implementation shape (a
  recursive builder threading entity-ID/rename state through every
  directory level, touching `Offer.HC`'s own live dispatch directly)
  made the actual size of "one slice" clear.
- **Wire the primitive into `hgit offer`'s live dispatch immediately
  once built**: rejected for this slice - `find_mask`'s own semantics
  (currently: one wildcard within one flat directory) would need a
  real, separate CLI decision before every existing real offering
  this project has ever made keeps behaving identically; safer to
  prove the primitive standalone first.
- **Full cross-directory rename detection from the start** (a file
  moved to a different subdirectory keeps its identity): rejected for
  this slice - would need searching the *entire* old tree recursively
  for every unmatched new file, a real performance and disambiguation
  question (multiple candidates at different depths) not yet
  evidenced as necessary; same-directory-position matching is the
  simpler, already-proven pattern to extend first.

## What this slice does not do

- Wiring into `hgit offer`'s own live dispatch (see Decision point 2).
- Cross-directory rename/move detection (see Decision point 1).
- `Check.HC`/`Status.HC`/`Diff.HC`/rendering-command awareness of
  nested trees - all real, separate follow-up work, not decided here.

## What would justify revisiting this

- The standalone primitive (probe 90) proving solid enough to justify
  the real `hgit offer` CLI-semantics decision.
- Real usage showing same-directory-position-only rename tracking is
  too limited (files routinely moved between directories in normal
  workflows).
