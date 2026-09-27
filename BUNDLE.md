# hgit exchange files: bundles (`.hgb`) and have-files (`.hgh`) — version 1

**Status: draft, an optional extension.** Specified by
[ADR 0020](docs/adr/0020-incremental-exchange-bundles.md). The canonical
repository format (`FORMAT.md`) is unchanged: a bundle is a separate file that
*carries* objects between repositories, and nothing in a bundle changes what a
`.hgs` or `.hgs.m` file means. A reader that does not implement this document
is unaffected by it. As of 1.9.0 only `hgit-native` implements bundles;
TempleOS exchanges repositories with `export`/`import` (whole files), and can
verify a bundle's objects only by applying it on a native host first.

## What a bundle is, and is not

A bundle is a set of immutable, content-addressed objects plus a manifest that
names *proposed* path heads and the commits the recipient must already have
(*prerequisites*). Applying it adds the objects the recipient lacks, then
proposes head updates that the recipient's own policy decides
(fast-forward, keep both, or refuse). It is:

- **an integrity-checked container**: every record carries its BLAKE2b-512
  hash and a footer hash covers the whole file;
- **not an authentication mechanism**: a hash proves the bytes are unchanged
  and internally consistent, not who produced them. There is no author
  identity or signature in hgit, so a recipient must obtain a bundle over a
  channel it trusts, or compare the printed bundle id out of band;
- **not live synchronization**: it is a file, produced from one repository
  state and applied to another, with no protocol between them;
- **not a way to move mutable state**: a bundle never carries `.hgs.m`, the
  current path, undo/redo logs, an in-progress merge, or closed-path markers.

## Layout

```
[16-byte header]
[record 0        ]   manifest   (type tag 0x10)
[records 1 .. N  ]   objects    (type tags 1..5, exactly as in a .hgs)
[record N+1      ]   footer     (type tag 0x11)
```

Every record uses the archive framing of `FORMAT.md` unchanged:
`[U64 length LE][data][64-byte BLAKE2b-512 of data]`, where `data` is one type
tag byte followed by the content. All integers are little-endian.

### Header (16 bytes)

| Offset | Size | Field | Meaning |
|---|---|---|---|
| 0 | 4 | magic | ASCII `H` `G` `B` `0` for a bundle |
| 4 | 2 | version | `U16`, currently `1` |
| 6 | 2 | reserved | must be written as `0`; readers ignore it |
| 8 | 8 | record_count | `U64`, the exact number of records that follow, manifest and footer included |

The magic differs from a repository's `HGS0`, so a bundle can never be
mistaken for a repository and a repository can never be applied as a bundle.
`record_count` is a cross-check only: a reader never allocates from it.

### Manifest (tag `0x10`)

Content, in order:

```
U8   manifest_version        1
U32  required_caps           bitmask; a reader that does not know a set bit MUST refuse the bundle
U32  optional_caps           bitmask; unknown bits are ignored
U8   hash_alg                1 = BLAKE2b-512 (the only defined value; anything else: refuse)
U8   kind                    1 = baseline (no prerequisites), 2 = incremental
U64  created_ms              creation time, ADR N-0001 units; informational, never used for ordering
U8   label_len               0..63
     label                   the sender's label: printable ASCII, no spaces; informational, and the name
                             suffix a recipient uses when it must keep a divergent head (see below)
U32  prereq_count
     prereq_count x 64 bytes commit hashes the recipient MUST already hold
U32  head_count
     head_count x { U8 name_len (1..63); name; 64-byte head commit hash }
U32  object_count            number of object records (excludes manifest and footer)
U64  object_bytes            sum over object records of (8 + length + 64)
```

No required or optional capability is defined in version 1; writers set both
masks to `0`. Reserved for later: a `chunked-blobs` capability and an advisory
"closed path" announcement part (neither exists in 1.9.0).

`prereq_count` is `0` exactly when `kind` is baseline. Heads are *proposals*:
the recipient's policy decides what happens to each.

### Objects (tags 1..5)

Ordinary object records: blob `1`, tree `2`, commit `3`, attrs `4`, conflict
`5`, with the encodings of `FORMAT.md`. A writer emits them in a deterministic
order (depth-first post-order from the heads in name order, children before
parents, each object once) so the same inputs always produce the same bytes and
the same bundle id. A reader MUST NOT depend on the order.

A bundle contains exactly the objects reachable from its proposed heads that
are not reachable from its prerequisites. It never contains an object that is
only reachable through a conflict record, an operation log, or a redo log,
because those belong to the sender's mutable state.

### Footer (tag `0x11`)

Content: `U8 footer_version (1)` then the 64-byte BLAKE2b-512 of **every byte of
the file before the footer record** (header, manifest and all object records).
That value is the **bundle id**; tools print it (first 16 hex digits are
enough for a filename) so it can be compared over another channel.

The footer exists because each record verifies itself but a truncated or
edited bundle can still end on a record boundary with every remaining record
valid. Without the footer a dropped record in the middle would be
indistinguishable from a smaller bundle.

## Have-file (`.hgh`)

A recipient exports a small file describing what it holds so a sender can build
a minimal incremental bundle in one round trip, with no network.

```
[16-byte header]   magic HGH0, U16 version 1, U16 reserved, U64 record_count (2)
[record 0]         have manifest (tag 0x12)
[record 1]         footer (tag 0x11), as above
```

Have manifest content:

```
U8   have_version            1
U8   label_len; label        the recipient's label
U32  head_count;   head_count x { U8 name_len; name; 64-byte head hash }
U32  sample_count; sample_count x 64-byte commit hashes
```

The sample is, for each head, up to K first-parent ancestors (K defaults to 64,
bounded), deduplicated. A have-file is a **hint**, never trusted: a sender uses
it only to choose prerequisites, and the recipient re-verifies every
prerequisite when it applies the bundle.

## Building a bundle

1. Choose the paths to send (default: every open path). Their heads are the
   proposed heads.
2. Choose prerequisites: with a have-file, the maximal commits among
   `have heads + samples` that exist in the sender's store and are ancestors of
   (or equal to) a proposed head; with explicit `--base` commits, those; with
   neither, none (a baseline bundle).
3. If a have-file was given and none of its commits is usable, fall back to a
   baseline bundle and say so. Never produce a partial bundle silently.
4. Objects = closure(proposed heads) minus closure(prerequisites), each once.

## Applying a bundle

Applying is two phases; nothing changes on disk until the first ends
successfully.

**Phase 1, verify (reads only).**

1. Header magic and version; manifest present as record 0 and footer last;
   `required_caps` known; `hash_alg` known. Otherwise refuse.
2. Every record: length fits in the remaining bytes (a length is never trusted
   for an allocation), the stored hash equals the recomputed hash, the type tag
   is legal for its position. Objects are decoded with the strict decoders of
   `FORMAT.md`; a malformed object refuses the bundle.
3. `record_count`, `object_count` and `object_bytes` match what was read. The
   footer hash matches the bytes before it.
4. Every prerequisite commit exists in the recipient. If any is missing,
   refuse, print the missing hashes, and suggest a baseline bundle.
5. Every reference made by a bundle object (commit to tree, parents, relation
   target and attrs; tree to children) resolves inside the bundle or the
   recipient, and every proposed head is a commit that does. Objects in a
   bundle that no proposed head reaches are reported and allowed.

**Phase 2, commit (writes).** New objects are added once each (ADR 0019); heads
are then decided per path:

| Local situation for a proposed head | Outcome |
|---|---|
| no such path, never existed | declare it with the incoming head |
| local head equals incoming | nothing |
| incoming is an ancestor of the local head | nothing (already contained) |
| local head is an ancestor of incoming | **fast-forward** the local path |
| neither is an ancestor of the other | **divergent**: keep the local head, and record the incoming head under a new path named `<path>@<label>` |
| path was closed locally | never reopen it; record under `<path>@<label>` and report |
| a merge is in progress on that path | do not move it; record under `<path>@<label>` and report |

`<path>@<label>` is an ordinary named path; the user combines it with the local
path using the existing `merge` command. If `<path>@<label>` already exists,
the same table applies to it, and a divergent update is kept under
`<path>@<label>+<first 8 hex of the head>`. Nothing is ever overwritten, and
every moved path gets an ordinary operation-log entry, so `undo` reverses it.
If a composed name would exceed 63 bytes the apply refuses with a clear message
before writing anything.

Applying the same bundle twice adds no objects and moves no head. An
interrupted apply leaves the previous state intact (objects that were written
but not yet referenced are ordinary dangling objects, which `check` reports and
a re-run completes).

## Failure semantics, in one place

- Any Phase 1 failure: nothing on disk changes.
- A crash during Phase 2: the archive and metadata are each replaced
  atomically, archive first. The worst outcome is objects with no head
  referencing them (dangling, harmless, completed by re-running).
- A corrupt or truncated bundle can never expose a head: heads are decided only
  after the footer and every record verified.

## Not in version 1

Delta or compressed records, chunked blobs, promised (absent) objects, signed
bundles, propagation of closed paths, transfer of dangling objects, and a
TempleOS implementation.
