# ADR 0013 — `hgit check`: repository integrity verification

## Status

**Implemented, written up retroactively.** `Check.HC`'s own header
comment has referred to "the ADR addendum below" since probe 72 added
dangling-object detection - but no governing ADR ever actually existed
for this file, a real gap this ADR closes (the comment's own internal
reference finally points somewhere real). Same reasoning as ADR 0011/
0012: a real, substantial, still-live architectural decision - three
real slices, built incrementally across probes 64/67/72 - deserves
one, whenever the gap is noticed.

## Context

The original brief's own command list included a "shrine check" - a
repo-integrity verification command - that was never wired in as M1's
command surface grew (`init`/`offer`/`status`/`history`/`see`, then
M2-M4's own additions). Real `git fsck`
(`git-scm.com/docs/git-fsck`, confirmed via its actual docs, not
assumed) names three real, distinct failure categories worth checking
independently: hash-integrity corruption, missing objects (a
commit/tree referencing a hash with nothing behind it), and dangling/
unreachable objects (present in the store, but not reachable from any
real ref). Building all three at once, before any real evidence
existed that hgit's own object store needed each one, would have been
exactly the kind of premature completeness this project's own standing
discipline (ADR 0007's "no guessed cap" lesson, generalized) argues
against.

## Decision

**Three real, incremental slices, matching this project's own
established incremental-ADR pattern**, each shipped once the previous
one was proven solid:

1. **Hash integrity first** (probe 64) - a thin wrapper over M0's own
   already-tested `ArchiveVerify`: recompute every stored object's own
   hash and compare against what it claims to be. Verified against
   both a real clean repo (`CHECK_OK`) and a deliberately-induced
   failure (one byte flipped inside a real repo's object section,
   correctly reporting `CHECK_FAIL objects=3 ok=2 corrupt=1`, not a
   false pass or a crash).
2. **Referential integrity second** (probe 67, extending an initial
   version) - a real, direct analogue of `git fsck`'s own most common
   real failure mode: walk every commit's own parent(s)/tree/relation-
   target and every tree's own child entries, confirming each hash
   actually resolves to a real object in the same store. Reports each
   broken reference by name (`commit_tree_missing`/`commit_parent_missing`/
   `relation_target_missing`/`tree_child_missing`), not just a pass/
   fail count - a real, actionable signal, not a black box.
3. **Dangling/unreachable detection third** (probe 72) - the one
   category deliberately deferred from the first slice, since it
   needs a real reachability walk from every ref this project hadn't
   built the machinery for yet. `CheckMarkReachable` walks the real
   object graph from every declared path's own HEAD (not just
   `"main"`'s - `Meta.HC`'s own `MetaPathListInto`), marking a parallel
   `reachable[]` array; anything left unmarked afterward is reported
   dangling. Verified against a real, naturally-occurring case (`hgit
   undo` leaves a commit's own unique objects genuinely unreachable,
   without destroying them - hgit's own non-destructive-history design
   makes this a real, everyday occurrence, not a contrived test).

**Both the referential-integrity and reachability passes are
generic per-object-type, not depth-aware** - this was a real,
deliberate design property from the start (not an accident later
discovered useful): a nested tree object (ADR 0010) gets exactly the
same treatment as a top-level one, because neither pass special-cases
depth at all. This was verified directly, not assumed, once ADR 0010
made it relevant (probe 92's own adversarial nested-tree-corruption
test) and again once ADR 0011 made real multi-parent commits possible
(probe 97's own manually-constructed 2-parent commit round-tripping
correctly through both passes with zero code changes).

## A real correctness bug found and fixed along the way

Probe 72's own dangling-detection pass initially reported false
positives: this project's own object store never deduplicates
identical content (the same file re-offered across many probes
produces the exact same hash at multiple archive positions), and the
first version of `CheckMarkReachable` only ever marked whichever
position it found *first* as reachable - every other position holding
that identical hash was equally reachable (same hash = same content)
but never marked. Fixed with a real coalescing pass: any position not
yet marked, whose hash matches an already-reachable position, is
marked too - no fixed point needed, since a duplicate's own outgoing
references are byte-identical to the original's and already resolved.
Caught by testing against a real, long-lived repo accumulated across
many probes, not a fresh, artificial fixture - a real instance of this
project's own standing lesson that synthetic test data can hide bugs a
real corpus surfaces.

## Alternatives considered

- **Build all three checks in one slice**: rejected - no real evidence
  yet (at probe 64's own time) that hgit's real object store needed
  referential-integrity or dangling checks specifically; each slice
  was built once its own real trigger existed (an actual real-world
  scenario the previous slice's own gap left unaddressed).
- **A single pass-or-fail signal instead of per-category, per-object
  reporting**: rejected - matching real `git fsck`'s own convention of
  naming exactly what's wrong (which object, which kind of problem),
  not just whether something is.

## What this does not do

- No repair/recovery mechanism - `hgit check` only reports, it never
  attempts to fix a corrupt object, a broken reference, or reclaim a
  dangling one. Real, separate follow-up work if ever needed - this
  project's own non-destructive design means a dangling object is
  already safe (nothing destroys it), so recovery mainly matters for
  genuine corruption, which has no real evidence of occurring outside
  deliberately-induced test cases so far.
- No automatic periodic/background checking - `hgit check` is only
  ever run on demand.

## What would justify revisiting this

- Real evidence of genuine (not deliberately-induced) object
  corruption in practice - would justify a real repair mechanism.
- A real object store large enough that a full linear scan (every
  check pass here is O(objects)) becomes a practical performance
  concern - no evidence of this at hgit's current real scale (low
  hundreds of objects across every repo this project has built).
