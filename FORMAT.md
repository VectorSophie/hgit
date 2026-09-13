# hgit `.HGS` archive format — version 1 (draft)

**Status: draft, M0-stage.** Implemented and verified end-to-end on real
TempleOS (`src/hgit-core/Hgs.HC`, `src/hgit-core/Archive.HC`,
`experiments/06-hgs-format/`). Not yet frozen — no repository written
with this format should be treated as durable across format changes
until this document says version 1 is stable (see ADR 0001).

## Layout

```
[16-byte header]
[object record 0]
[object record 1]
...
[object record N-1]
```

## Header (16 bytes, all multi-byte fields little-endian)

| Offset | Size | Field | Meaning |
|---|---|---|---|
| 0 | 4 | magic | ASCII bytes `H` `G` `S` `0` (0x48 0x47 0x53 0x30) |
| 4 | 2 | format_version | `U16`, currently `1` |
| 6 | 2 | reserved | Must be written as `0`. Readers must not reject a nonzero value (no meaning assigned yet) but must not assume anything about it either. |
| 8 | 8 | object_count | `U64`, number of object records that follow |

A reader must check the 4-byte magic before trusting anything else in
the file. `HgsReadHeader` (`src/hgit-core/Hgs.HC`) returns `FALSE` rather
than guessing if the magic doesn't match.

## Object record

```
[8 bytes: U64 length, little-endian]
[`length` bytes: raw content]
[64 bytes: BLAKE2b-512 hash of the content, per RFC 7693]
```

The hash is stored, not just computable — a reader can verify each
record independently without hashing the whole file, and corruption in
one record doesn't require re-deriving what the hash "should" be from
context. `ArchiveVerify` (`src/hgit-core/Archive.HC`) does exactly this:
scans records, recomputes each hash, and reports how many match.

No length limit is enforced by the format itself, and none is imposed by
hashing any more either: `ArchivePut`/`ArchiveVerify`/`HgsPut` all call
`B2Hash512Any` (`Blake2b.HC`'s streaming wrapper — verified on 200- and
300-byte messages against a host oracle, `experiments/08-blake2b-streaming/`
and `experiments/09-wire-streaming-hash/`), not the 128-byte-capped
`B2Hash512`. The one remaining size limit is `ObjectPut`'s own
`tagged[128]` scratch buffer (a fixed-size-local implementation detail,
not a format or hashing limitation) — real next work if a tagged object
needs to exceed that.

## Object typing

A record's content may itself begin with a **type tag byte**, prepended
before the content is hashed and stored (`src/hgit-core/Object.HC`,
`experiments/07-object-typing/`):

| Tag | Meaning |
|---|---|
| 1 | `OBJ_BLOB` |
| 2 | `OBJ_TREE` |
| 3 | `OBJ_COMMIT` (hgit's own vocabulary — "offering" — will map onto this at a higher layer; not yet designed) |

The tag participates in the BLAKE2b hash (matching Git's
`"<type> <size>\0<content>"` header-in-hash approach) specifically so
identical bytes stored as different types never collide at the
content-address level — verified directly: the same 3 bytes tagged
`OBJ_BLOB` vs. `OBJ_TREE` produce different hashes. This is a convention
layered on top of the generic `.HGS` record, not a change to the record
format itself — a reader that doesn't know about type tags still sees a
valid, hashable byte string, just one whose first byte happens to be
semantically meaningful to typed readers.

## Tree object content

An `OBJ_TREE` object's content (`src/hgit-core/Tree.HC`,
`experiments/10-tree-object/`) is a flat entry list:

```
U32 entry_count
repeated entry_count times:
  U8 name_len
  name_len bytes of name
  U8 child_type   (OBJ_BLOB or OBJ_TREE)
  64 bytes child_hash
  U64 entity_id (LE)
```

A tree entry's `child_hash` can point at another tree - real, nested
directories, built and consumed by `hgit offertree` and recursed into
by `statustree`/`diff`/`see`/`check`/`merge` (`docs/adr/0010-subdirectory-support.md`,
probes 88-100), not just a flat, single-level format capability
anymore.

`entity_id` (added per `docs/adr/0004-stable-entity-identity.md`,
`experiments/49-entity-id/`) is a stable identifier for "this tracked
name," independent of its content hash — generated once (two `RandU32`
reads combined into a `U64`) the first time a name appears in any tree
this repo has built, and copied forward unchanged into every later
tree that still has an entry for that same name (`Offer.HC` does the
carrying-forward, by looking up the parent commit's own tree before
building the new one). Deliberately minimal: same name = same
identity; an actual rename is not detected and gets a fresh ID - see
ADR 0004's own scope notes. **Breaking format change**: repos built
before this change used a 65-byte entry shape (no `entity_id` field);
this is not migrated, matching this project's stated "no released
users yet" stance on breaking changes (same as ADR 0003's own
migration non-goal).

## Commit object content

An `OBJ_COMMIT` object's content (`src/hgit-core/Commit.HC`,
`experiments/11-commit-object/`):

```
64 bytes  tree_hash
U8        parent_count
repeated parent_count times: 64 bytes parent_hash
U64       timestamp (LE)
U32       message_len (LE)
message_len bytes of message
U8        relation_tag  (0=none/plain continuation, 1=CONTINUES explicit,
                         2=CORRECTS, 3=REVERTS, 4=RECONCILES)
if relation_tag != 0:
  64 bytes relation_target_hash
  U64      relation_entity_id (0 = not entity-scoped, applies to the
                               whole commit; otherwise names an entity
                               ID from a tree entry, see below)
```

Verified with a real two-commit chain: a root commit (`parent_count=0`)
and a child commit (`parent_count=1`) whose parent hash is the root
commit's own computed hash — the actual point of the design (naming an
ancestor by content address), not just "a commit object exists."

`relation_tag`/`relation_target_hash` (added per
`docs/adr/0005-typed-relation-vocabulary.md`,
`experiments/50-relation-vocabulary/`, wired into real
`hgit correct`/`revert`/`reconcile` commands in
`experiments/51-relation-commands/`) let a commit name an explicit
typed relationship to an earlier commit (not necessarily its direct
parent), beyond plain "comes after." `relation_tag=0` is the default
for every ordinary offer and costs exactly one byte; only commits that
record a richer relation pay the extra bytes.

`relation_entity_id` (added per
`docs/adr/0006-entity-scoped-relations.md`,
`experiments/53-entity-scoped-relations/`) lets a relation optionally
name a specific tracked entity (ADR 0004's per-tree-entry ID) within
the commit, rather than the commit as a whole. `0` is a practical
"unscoped" sentinel, not formally collision-proof (same honest caveat
as `OpLog.HC`'s all-zero `prev_head` sentinel) — a real
`GenerateEntityId()` landing on exactly `0` is vanishingly unlikely.
Entity IDs are printed/parsed as 16-char hex (`Hex.HC`'s
`U64ToHex`/`HexToU64`), not plain decimal — a `U64` with the high bit
set prints as a negative number under a plain `%d`, a real
hit-in-practice issue (see probe 49's own README) that hex avoids.
**Breaking format change**: repos built before this are not migrated
(same stance ADR 0003/0004/0005 already took).

No author/identity field yet — deliberately deferred further into M3
per the product thesis's "stable entity ID"/"human mark" concepts;
ADR 0004 covers the entity-ID half, this covers the relation-vocabulary
half; author/identity itself is still not invented.

## What this format deliberately does NOT have yet

- ~~No merge commits tested~~ **Resolved** (`docs/adr/0011-merge.md`,
  probes 97-100): `parent_count > 1` is real, exercised, committed
  code now, not just a format capability — `hgit merge` builds a real
  2-parent commit whenever a real, non-conflicting (or fast-forward)
  merge succeeds, verified round-tripping through `Check.HC`'s own
  referential-integrity and reachability passes (both already looped
  over every real parent generically, needing zero changes either).
- ~~No recursive-tree test~~ **Resolved** (`docs/adr/0010-subdirectory-support.md`,
  probes 88-96): a real tree entry with `child_type = OBJ_TREE`,
  pointing at another real, separately-stored tree object, is now
  built and consumed by real commands — `hgit offertree` builds one
  from a genuine on-disk directory tree, and `statustree`/`diff`/
  `see`/`check`/`merge` all correctly recurse into it. Not just the
  object model round-tripping in isolation anymore.
- **Index is linear-search, not a hash table yet.** `src/hgit-core/Index.HC`
  (`IndexBuild`/`IndexLookup`, `experiments/12-index/`) now answers
  "where is the object with this hash" — verified by fully dereferencing
  a tree entry's child hash through it back to real blob content — but
  the lookup itself is still a linear scan, and the index isn't
  persisted (rebuilt from a full scan every time). Real optimization,
  not yet needed at hgit's current scale.
- **No compression or delta encoding in the object store itself.**
  Every byte of every stored object is still raw. `src/hgit-core/Fossil.HC`
  (a real, verified-reliable delta format, `docs/adr/0008-fossil-delta-format-prototype.md`)
  is wired into `hgit offer`/`hgit status` for their own fuzzy rename
  detection (`FossilSimilarityPercent` - ADR 0009), but that's a
  similarity measure, not object storage compression. Whether/where
  the object store itself should adopt delta-compressed storage
  remains a real, separate, undecided architectural question.
- **No multi-file / sharding.** One archive is one file, matching RedSea's
  contiguous-file model and Fossil's single-file-database precedent
  (doc 04) — not Git's directory-sharded loose objects.

## Verified test vector

`experiments/06-hgs-format/tested_source.hc` builds a 2-object archive
(`"hgitA"`, `"hgitB"`, 5 bytes each), writes it to `C:/Home/test2.hgs` on
real TempleOS via `FileWrite`, reads it back via `FileRead`, and confirms:
header magic/version/count all correct, and both objects' stored hashes
match freshly recomputed ones. Total file size for that fixture: 170
bytes (16-byte header + 2 × 77-byte records). See that probe's `README.md`
for the exact commands and raw output.

## Versioning policy (forward-looking, not yet exercised)

`format_version` exists so a future incompatible change bumps this
number rather than silently breaking old archives. No migration path
has been needed or built yet — version 1 is the only version that has
ever existed. Per the brief's own discipline, an incompatible change
gets a new version number and a documented migration note here, not a
silent redefinition of what version 1 means.
