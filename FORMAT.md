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
```

A tree entry's `child_hash` can point at another tree (nesting/recursion
is supported by the format), but this has not been tested yet — only a
flat, single-level, two-entry tree has been verified so far.

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
```

Verified with a real two-commit chain: a root commit (`parent_count=0`)
and a child commit (`parent_count=1`) whose parent hash is the root
commit's own computed hash — the actual point of the design (naming an
ancestor by content address), not just "a commit object exists."

No author/identity field yet — deliberately deferred to M3 per the
product thesis's "stable entity ID"/"human mark" concepts; not invented
ahead of that milestone.

## What this format deliberately does NOT have yet

- **No merge commits tested** — the format's `parent_count` supports
  more than 1, but only 0 and 1 have been exercised.
- **No recursive-tree test** — the format supports a tree entry pointing
  at another tree, but no test has built one yet.
- **Index is linear-search, not a hash table yet.** `src/hgit-core/Index.HC`
  (`IndexBuild`/`IndexLookup`, `experiments/12-index/`) now answers
  "where is the object with this hash" — verified by fully dereferencing
  a tree entry's child hash through it back to real blob content — but
  the lookup itself is still a linear scan, and the index isn't
  persisted (rebuilt from a full scan every time). Real optimization,
  not yet needed at hgit's current scale.
- **No compression or delta encoding.** Every byte of every object is
  stored raw. Deliberate for now — no compression should be added
  without corpus evidence per the brief's own discipline.
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
