# ADR 0010 — Subdirectory support: scope for a first real slice

## Status

**Implemented (first slice).** This ADR exists because probes 88 and
89 established real evidence for the first time (recursive directory
walking is buildable; nested `OBJ_TREE` objects round-trip correctly
through the existing object model, zero code changes) - per this
project's own standing discipline, no ADR gets written before its
supporting evidence exists, and this is that evidence. Probe 90 then
built the standalone primitive, and probe 91 made the real
CLI-semantics decision (Decision point 2, below) and wired it in: a
**new, separate command, `hgit offertree`**, not a change to plain
`hgit offer`.

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
2. **Resolved in probe 91: a new, separate command, `hgit offertree
   <repo> <dir_path> <message>` - not a change to `hgit offer`'s own
   live dispatch.** `HgitOfferTree` (`Offer.HC`) reuses
   `HgitOfferWithRelation`'s own repo-loading/archive-sizing/
   parent-lookup/commit/HEAD/oplog conventions, substituting
   `TreeBuildRecursive` for the flat `FilesFind` loop. This keeps
   `find_mask`'s existing flat semantics completely unchanged for every
   prior real offering this project has ever made, at zero regression
   risk - the original concern this decision point raised. Verified
   end-to-end (probe 91): a real nested tree (`SEE_TREE entries=2`,
   one `OBJ_TREE` subdirectory entry, one `OBJ_BLOB` file entry),
   `hgit check` passing at the level `Check.HC` currently verifies, and
   entity-ID continuity (both the subdirectory's own tree-entry ID and
   the nested file's ID unchanged) across a second `offertree` call
   that edited only the nested file. No relation-tag (`correct`/
   `revert`/`reconcile`) support yet - a real, separate follow-up.
3. **`Check.HC` already covers nested trees correctly - re-examined
   after probe 91, not a real gap after all.** This slice's own
   original draft (and probe 91's first write-up) assumed `Check.HC`
   would need real, separate work to recurse into a nested tree's own
   children. Re-reading `Check.HC` itself shows this concern doesn't
   apply: both its referential-integrity pass (a flat scan over every
   archive record, generic per-object-type - not a walk that starts at
   a commit's tree and stops one level down) and its
   reachability/dangling pass (`CheckMarkReachable`, plainly recursive
   - it looks up any hash's real stored object type and recurses into
   ITS children too, with no depth limit) already treat a nested
   `OBJ_TREE` record exactly like a top-level one, because neither
   pass is depth-aware in the first place. Probe 91's own real
   captured evidence confirms this in practice, not just by code
   reading: `CHECK_OK objects=5` (commit + top-level tree + `top.txt`
   blob + `SubA`'s own nested tree + `inner.txt` blob), `CHECK_REFS_OK`
   (the flat scan visited `SubA`'s own tree record and validated its
   child hash), `CHECK_DANGLING_NONE` (the recursive walk reached
   `inner.txt`'s blob through `SubA`'s own tree entry - it would show
   dangling otherwise, since nothing else points at it directly). The
   adversarial case (deliberately breaking a reference *inside* a
   nested tree, to directly observe `CHECK_BROKEN_REF`/dangling firing
   on nested content, rather than just this positive "nothing's wrong"
   case) is now run too (probe 92, `experiments/92-check-nested-
   corruption/`): one byte of `SubA`'s own `inner.txt` entry's
   `child_hash` flipped in place (not re-hashed, so every OTHER real
   reference to `SubA` stays valid - isolates exactly one failure).
   Real result: `CHECK_BROKEN_REF tree_child_missing <hash>` (the flat
   scan found the broken reference *inside* `SubA`'s own content) and
   `CHECK_DANGLING blob <hash>`/`CHECK_DANGLING_COUNT 1` (the
   recursive reachability walk correctly lost `inner.txt`'s real blob
   once its only real reference broke) - both firing from a
   corruption that exists only inside a nested tree, confirming the
   negative case matches the positive one probe 91 already showed.

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

- Modifying `hgit offer`'s own live dispatch - `offertree` is a
  separate command instead (see Decision point 2).
- Cross-directory rename/move detection (see Decision point 1).
- `Status.HC`/`Diff.HC`/rendering-command awareness of nested trees -
  `See.HC` closed (probe 93, `experiments/93-see-nested-trees/`:
  `SeePrintTreeEntries` recurses into any `OBJ_TREE` entry, indenting
  one level deeper, verified on a real 2-level-deep repo). `Diff.HC`
  now also closed (probe 94, `experiments/94-diff-nested-trees/`:
  `DiffPrintTreeChanges` recurses into a modified/new/deleted
  subdirectory, path-prefixing every real change - `SubA/inner.txt`,
  not just `SubA`; a same-name kind change reported as a real, honest
  `DIFF_TYPE_CHANGED` rather than guessed at). `HistoryDoc.HC`/
  `ReconcileDoc.HC`/`Graph.HC` don't touch tree/file content at all (a
  re-read while writing this up found they render commit chains/
  relations/branches only, never a file listing - "flat" doesn't
  apply, and neither does this item) - only `Status.HC` (comparing a
  live directory against nested trees) remains genuinely open here.
- `offertree` relation-tag support (`correct`/`revert`/`reconcile`
  equivalents) - a plain offering only, matching `HgitOffer`'s own
  original scope before ADR 0005 added relations.

## What would justify revisiting this

- Real usage showing same-directory-position-only rename tracking is
  too limited (files routinely moved between directories in normal
  workflows).
- Real usage of `offertree` showing the lack of relation-tag support
  (`correct`/`revert`/`reconcile`) is a practical blocker.
