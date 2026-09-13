# ADR 0005 — Typed relation vocabulary: an optional relation tag + target on every commit

## Status

**Minimal first slice implemented and verified**
(`experiments/50-relation-vocabulary/`, PASS). `Commit.HC`'s content
format carries `relation_tag`/`relation_target_hash` after the message;
`CommitRelationTag`/`CommitRelationTarget` accessors verified to
round-trip correctly alongside a real message, timestamp, and parent
count, and a real `hgit offer`'s `REL_NONE` case confirmed unaffected
(regression check). Builds directly on ADR 0004 (stable entity IDs,
implemented and verified in probe 49) and covers the second half of
the brief's M3 milestone: a small typed relation vocabulary —
CONTINUES, CORRECTS, REVERTS, RECONCILES — describing how one offering
relates to a prior one, beyond the plain parent-chain "came after"
relationship `Commit.HC` already encodes. **Not yet done**: no CLI
command produces a relation (storage layer only), and relations are
not yet entity-scoped — both still accurate to this ADR's own stated
scope below.

## Context

Every commit already has an implicit relation to its parent: it
*continues* it, in the sense of "this is the next state after that
one." That's not enough to express the brief's richer vocabulary — a
commit that **fixes a mistake** in an earlier one (CORRECTS), **undoes**
an earlier one's changes (REVERTS), or **brings two diverged lines back
together** (RECONCILES) is doing something more specific than plain
continuation, and a real history view (`hgit historydoc`, `hgit see`)
or reconciliation UI needs to be able to tell the difference and show
it.

ADR 0004 already anticipated this: "commit B CORRECTS commit A needs
to name which entity within each commit the correction applies to, not
just that commit B follows commit A." This ADR takes a narrower first
step: relate commit-to-commit (not yet entity-scoped within a commit) —
getting the vocabulary itself to exist and round-trip correctly before
adding the harder question of "which specific tracked file, within a
multi-file commit, does this relation apply to."

## Alternatives considered

- **Relate commits AND scope to a specific entity ID in the same first
  slice**: rejected as too much at once. Doing it in two steps (plain
  commit-to-commit relation first, entity-scoping later) matches this
  project's own established pattern of shipping the smaller, testable
  slice first (e.g. ADR 0004 itself: entity IDs before any relation
  vocabulary used them).
- **A separate object type for relations** (e.g. an `OBJ_RELATION`
  record referencing two commit hashes, stored independently of either
  commit): rejected for this slice — every relation in the brief's
  vocabulary is a property of ONE commit's relationship to an earlier
  one, so storing it as a field ON that commit is simpler and needs no
  new indexing question ("find all relation-records naming commit X").
  Worth reconsidering if relations ever need to be many-to-many or
  attached after the fact (this slice requires stating the relation at
  offer time).
- **Encoding the relation in the commit MESSAGE as a convention** (e.g.
  a magic prefix string): rejected — unstructured text conventions are
  exactly the kind of implicit-and-fragile design the brief's explicit
  typed-vocabulary request is pushing back against.

## Decision

Extend `Commit.HC`'s content format with two new trailing fields,
after the message:

```
U8  relation_tag   (0 = none/plain continuation, 1 = CONTINUES
                     [explicit], 2 = CORRECTS, 3 = REVERTS,
                     4 = RECONCILES)
if relation_tag != 0:
  64 bytes relation_target_hash   (the prior commit this relation
                                    names - NOT necessarily the same
                                    as the parent hash; a correction
                                    can name a commit several steps
                                    back, not just the immediate
                                    parent)
```

`relation_tag == 0` (the default for every ordinary `offer`) costs
exactly one byte and changes nothing about existing behavior — the
implicit "continues its parent" relationship every commit already has
via the parent chain is unaffected. Only commits that explicitly
record a richer relation pay the extra 64 bytes.

## What this slice does not do

- **No entity-scoping.** A relation names a target COMMIT, not a
  specific tracked file/entity within it. "Commit B corrects commit A"
  is expressible; "commit B corrects specifically what commit A did to
  file X" is not, yet.
- **No semantic enforcement.** Nothing checks that a CORRECTS/REVERTS
  target hash actually exists in the repo, or that RECONCILES's target
  is genuinely a divergent line rather than an ancestor — this slice
  is pure storage + accessors, same "encode/decode only, no policy"
  scope every other object-format ADR here has taken first.
- **No CLI command wiring yet.** `Offer.HC`/`Hgit.HC` need a way for a
  real `hgit` invocation to specify a relation (e.g. a
  `hgit correct <repo> <target_hash> <find_mask> <message>` command) -
  real follow-up work, not designed or built in this ADR.

## Costs

- A second breaking change to the commit object format in close
  succession to ADR 0004's tree-format change. Same "no migration,
  no released users yet" stance applies - not treated as a special
  problem, but worth naming so it isn't invisible.
- `CommitMessageLen`/`CommitMessage`'s existing accessors are computed
  from a running offset that already depends on `parent_count`; adding
  fields after the message keeps those two accessors' own math
  unchanged (a real, deliberate reason to put the new fields at the
  END rather than splicing them in earlier) - but any accessor reading
  PAST the message (the two new ones) must recompute from
  `CommitMessageLen`, not assume a fixed offset.

## What would justify revisiting this

- If entity-scoped relations turn out to need a fundamentally
  different storage shape (e.g. multiple relations per commit, one per
  affected entity) rather than one relation per commit - no evidence
  either way yet, this slice only supports one relation per commit.
- If real usage shows commits routinely need to express relations to
  MULTIPLE prior commits at once (not yet anticipated, not designed
  for).
