# ADR 0004 — Stable entity identity: a random per-entry ID in tree entries, minimal first slice

## Status

**Minimal first slice implemented and verified**
(`experiments/49-entity-id/`, PASS). `Tree.HC`'s entry format now
carries an 8-byte entity ID; `Offer.HC` carries it forward from the
parent commit's tree when a name persists, and generates a fresh one
otherwise. Verified: the same file name keeps the same ID across two
offers with different content (confirmed via real blob-hash
comparison that the content genuinely differed), a new name in the
same offer gets a distinct ID, and a name's ID survives being carried
forward through two full generations. This ADR covers the M3 starting
point per the brief's own milestone ordering (ADR 0001 explicitly
deferred "author/identity" concepts to M3, not designed there). It
intentionally does **not** solve full rename detection — see "What
this slice does not do" below, still accurate to what's built.

## Context

The product thesis's M3 milestone calls for **stable entity
identity** and a small typed relation vocabulary
(CONTINUES/CORRECTS/REVERTS/RECONCILES) on top of the content-addressed
object model M1/M2 already built. Content hashes (`Tree.HC`/`Object.HC`)
identify *what* a file's bytes are, and commit parent chains
(`Commit.HC`) identify *when* one project state followed another — but
nothing yet identifies "this is the same tracked thing across time,"
independent of both its content and its current name. That's a
distinct concept from anything built so far, needed before the
relation vocabulary can mean anything (e.g. "commit B CORRECTS commit
A" needs to name *which entity* within each commit the correction
applies to, not just "commit B follows commit A").

Before designing where this ID comes from, the real question was
whether TempleOS has a genuine random-number source to generate one.
Verified from primary source (`cia-foundation/TempleOS`,
`Kernel/BlkDev/FileSysFAT.HC`: `br->serial_num=RandU32;` — a real
filesystem serial number; `Demo/RandDemo.HC`: `RandU16`/`RandU32` used
for random pixel plotting) and confirmed empirically on real TempleOS
(`experiments/48-rand-for-identity/`): three successive reads of
`RandU32` returned genuinely distinct values
(`2182622941`, `2622862472`, `1307883381`). `RandU32` is a real,
usable 32-bit random source, not a function needing special
initialization syntax (used as a bare identifier, no parentheses) —
confirmed both from source usage and by direct test.

## Alternatives considered

- **Content-hash-based identity** (treat two blobs with the same bytes
  as "the same entity"): rejected as the *sole* mechanism — this is
  already what content-addressing gives for free, and it's the wrong
  notion for identity (a file renamed AND edited has neither the same
  path nor the same hash, but is still "the same entity" to a human;
  two unrelated files that happen to share content are NOT the same
  entity). Real rename/identity tracking needs something orthogonal to
  content.
- **Sequential integer IDs** (a per-repo counter): rejected — requires
  a single global counter stored somewhere and incremented atomically,
  adding a new kind of shared mutable state this project doesn't have
  yet (every existing concern in `Meta.HC` is either replace-on-write
  or accumulate-and-scan, not "read-modify-write a counter"). A random
  64-bit ID needs no coordination at all and collides with
  vanishingly low probability at hgit's target scale — same reasoning
  already accepted for the all-zero HEAD sentinel (`OpLog.HC`'s own
  documented caveat).
- **A single `RandU32` (32 bits) instead of combining two for 64
  bits**: rejected as the default — 32 bits collides too easily at even
  modest tree sizes (birthday-bound around ~65,000 entries for a 50%
  collision chance) for something meant to be a permanent identifier,
  whereas the existing content hash is already 512 bits. Two `RandU32`
  reads combined into a 64-bit ID is cheap and matches the scale of an
  ordinary identifier better without inventing a new PRNG.

## Decision

Extend `Tree.HC`'s entry format with a new 8-byte **entity ID** field
per entry: `[U8 name_len][name][U8 child_type][64-byte child_hash]`
becomes `[U8 name_len][name][U8 child_type][64-byte child_hash][8-byte entity_id]`.
The ID is generated once (two `RandU32` reads combined into a `U64`)
the first time a given name appears in *any* tree this repo has ever
built, and **copied forward unchanged** into every later tree that
still has an entry for that name — so the same tracked file keeps the
same ID across every ordinary `offer`, regardless of content changes.

This is a real, breaking change to the tree object format (`FORMAT.md`
needs updating once implemented) — existing test repos built under the
old format are not migrated by this ADR; that's a explicit
non-goal here, consistent with this project having no released users
yet (same stance ADR 0003 took about its own migration).

## What this slice does not do

- **No rename detection.** Copying an ID forward only works because
  the *name* stayed the same between offers. A file renamed between
  two offers gets a **new** ID under this slice — indistinguishable
  from a deleted file plus an unrelated new one. Real rename detection
  (e.g., matching by content hash when a name disappears and a new
  name appears with identical content) is real future work, not
  designed or built here.
- **No relation vocabulary yet.** CONTINUES/CORRECTS/REVERTS/RECONCILES
  need entity IDs to refer to *something* — this ADR only creates the
  IDs. The vocabulary itself, and where a commit records "this change
  relates to entity X via relation Y," is separate, later work.
- **No identity for commits or trees themselves**, only for tree
  *entries* (i.e. tracked files). Whether commits/paths need their own
  stable IDs (as opposed to being identified by their content hash and
  parent chain, which already works) is an open question, not decided
  here.

## Costs

- Every already-verified tree-object probe (10, 18-21, and everything
  built on top of `Tree.HC`/`Offer.HC`) used the old 65-byte entry
  shape; re-verifying the whole chain against the new 73-byte shape is
  real work, not done in this ADR.
- Fixed per-file overhead (8 bytes/entry) forever, for every tracked
  file, whether or not the relation vocabulary ever uses it — accepted
  as cheap at hgit's target scale (same "no premature optimization"
  stance as ADR 0001).

## What would justify revisiting this

- If real rename detection turns out to need a completely different ID
  scheme (e.g. content-hash-derived rather than random) to work
  correctly - not yet investigated.
- If 64 bits turns out to be measurably insufficient once real corpus
  benchmarking (doc 06, still not done) provides an actual entry-count
  ceiling to check against.
- **Update, 2026-09-14 (`docs/research/04-vcs-comparison.md`'s Breezy
  comparison), corrected same day**: this entry originally claimed
  hgit's entity id and its rename detector (ADR 0009) "never talk to
  each other" - that claim was checked against `Offer.HC`'s actual code
  and probe 84's own real test output and found **wrong**, not a real
  gap. `OfferFindFuzzyRename`/the exact-hash path both feed the SAME
  entity id forward on a detected rename (exact-content or fuzzy) -
  probe 84's own `test_driver.hc` directly confirms a renamed-with-edit
  file (`P84Renamed.txt`) carries the identical entity id
  (`6c3a916dbd13cb00`) its pre-rename self had. hgit's design is
  already closer to Breezy's own file-id-is-the-rename-mechanism
  approach than this entry first gave it credit for - the real
  difference from Breezy is narrower than originally stated: Breezy's
  CLI is explicitly rename-aware as a first-class operation, while
  hgit's detection is a same-offer, best-match heuristic (ADR 0009's
  own "no cross-file disambiguation" limitation) rather than a
  tool-driven rename command - a real but much smaller gap than "never
  talk to each other" implied. See `docs/research/failed-approaches.md`
  for the corrected record of this mistake.
