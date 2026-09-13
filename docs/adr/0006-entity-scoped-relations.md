# ADR 0006 — Entity-scoped relations: an optional entity ID on every relation

## Status

**Implemented and verified** (`experiments/53-entity-scoped-relations/`,
PASS). `Commit.HC` carries `relation_entity_id` (a `U64`, `0` =
unscoped) after `relation_target_hash`; `Hgit.HC`'s relation commands
accept it as a 16-hex-char argument. Verified with a real entity ID
read from an actual tree entry, and with the unscoped (all-zero)
sentinel case. Closes the gap ADR 0005 explicitly left open: "a
relation names a whole commit, not a specific tracked file/entity
within it."

## Context

ADR 0005 gave a commit an optional relation to an earlier commit
(CONTINUES/CORRECTS/REVERTS/RECONCILES + a target commit hash) —
verified real and working (probes 50-52). But "commit B corrects
commit A" is coarser than what a real reconciliation view usually
needs: a multi-file commit might fix one file's mistake while several
other files in the same commit are unrelated changes. ADR 0004 already
gives every tracked file a stable entity ID independent of its
content — the natural next step is letting a relation optionally name
*which* entity, within the target commit's tree, it actually concerns.

## Alternatives considered

- **One relation per entity, stored per tree entry** (extend
  `Tree.HC` again, put the relation on the entry instead of the
  commit): rejected — a relation is fundamentally about *what changed
  between two offerings*, which is a commit-level concept (comparing
  two trees), not a property of one entry in one tree taken alone. Ties
  the relation to the wrong object.
- **A list of entity IDs per relation** (a commit's relation could name
  several affected entities at once): rejected for this slice — no
  evidence yet that a single relation naming multiple entities is
  needed, and ADR 0005 already scoped "one relation per commit," not
  many; scoping to one entity per relation matches that existing
  choice rather than expanding it further without cause.
- **Requiring an entity ID whenever a relation exists** (no
  "unscoped" case): rejected — a real correction/revert/reconciliation
  might still legitimately apply to a commit as a whole (e.g. "this
  whole offering reverts that whole offering," not one specific file).
  Making entity-scoping optional, not mandatory, keeps ADR 0005's
  already-verified whole-commit case valid without change.

## Decision

Add one more trailing field to `Commit.HC`'s content, present whenever
`relation_tag != REL_NONE` (right after `relation_target_hash`):

```
U64 relation_entity_id   (0 = not entity-scoped - the relation applies
                          to the whole commit, ADR 0005's original
                          behavior; any other value names a specific
                          entity ID from ADR 0004's tree entries)
```

`0` is a safe sentinel for "not entity-scoped" for the same reason
`OpLog.HC`'s all-zero `prev_head` sentinel is: `GenerateEntityId()`
combines two `RandU32` reads into a full 64-bit value, so a genuine
entity ID landing on exactly `0` is vanishingly unlikely — not
formally proven collision-free, same honest caveat already accepted
elsewhere in this project.

`Offer.HC`'s `HgitOfferWithRelation` gains a `relation_entity_id`
parameter (`0` for the common, non-entity-scoped case — ADR 0005's
existing three commands keep working unchanged by passing `0`).
`Hgit.HC`'s relation commands gain a way to pass a real entity ID —
the concrete command shape is real follow-up work, not fully decided
in this ADR (see "Not yet done").

## What this slice does not do

- **Does not validate** that a given `relation_entity_id` actually
  appears in either commit's tree — pure storage, no policy, matching
  every other object-format ADR's own first slice.
- **Does not change how a user discovers an entity ID** to scope a
  relation to — `hgit see`'s tree listing already prints each entry's
  ID (added when `See.HC` was updated for ADR 0004), which is the
  existing way to find one; no new discovery UI designed here.
- **Does not support multiple entity-scoped relations per commit** —
  still one relation (now optionally one entity) per commit, per ADR
  0005's own scope.

## Costs

- A third breaking change to the commit object format in close
  succession to ADR 0004 (tree entries) and ADR 0005 (relation
  tag/target) — same "no migration, no released users yet" stance.
- The exact CLI shape for supplying an entity ID to `correct`/`revert`/
  `reconcile` needs a real design choice (e.g. an extra positional
  argument, defaulting to `0`) — left to the implementing probe, not
  fully specified here.

## What would justify revisiting this

- If real usage shows a single relation needs to name more than one
  entity at once (not anticipated, not designed for).
- If the `0`-means-unscoped sentinel ever needs to be distinguished
  from a genuine (if astronomically unlikely) all-zero entity ID -
  no evidence this matters at hgit's target scale.
