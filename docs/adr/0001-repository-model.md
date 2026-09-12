# ADR 0001 — Repository model: single self-contained append-only archive of content-addressed objects

## Status

Accepted for M1 scope. Stable identity, typed history relations, and
reconciliation representation are explicitly deferred to later ADRs (see
"What would justify revisiting this" below) — this ADR covers only the
base storage/object layer, per the brief's own milestone ordering (M0/M1
core, M3 for identity/relations).

## Context

The product thesis asks for a Git-like content-addressed snapshot model
as the base layer, enhanced with stable entity identity and a small
typed relation vocabulary (CONTINUES/CORRECTS/REVERTS/RECONCILES) —
explicitly *not* patch theory (Pijul/Darcs) without evidence. Three real
constraints narrow the actual design space beyond "just clone Git":

1. **RedSea is contiguous-file-only allocation** (doc 01), and TempleOS's
   own philosophy targets ~100MB total drive footprint — Git's
   loose-object-directory-plus-packfile split, sharded into 256
   subdirectories, is solving a scaling problem hgit doesn't have and
   a filesystem-flexibility assumption RedSea doesn't offer.
2. **hgit-core now has a working, tested primitive** for exactly "one
   file holding many content-addressed records" — `src/hgit-core/Archive.HC`
   (probe 05), verified end-to-end on real TempleOS: append, persist via
   `FileWrite`, read back via `FileRead`, per-record BLAKE2b
   verification. This is not a proposal, it's already running.
3. **Fossil's own model is a single self-contained artifact store**
   (doc 04) — one file, typed self-describing artifacts, no separate
   blob/tree/pack split — and its authors made that choice for reasons
   (single-file distribution, rebuildable state, simplicity) that line
   up with TempleOS's own stated constraints far better than Git's.

## Alternatives considered

- **Straight Git clone** (loose objects in a sharded directory tree +
  packfiles + refs + reflog): rejected as the base layer. Git's
  directory sharding and packfile delta-base selection exist to solve
  problems (huge repos, many loose files taxing real filesystems) that
  don't apply at hgit's target scale, and actively fight RedSea's
  contiguous-file model. The *content-addressing* idea is kept (see
  Decision); the *filesystem layout* is not.
- **Pijul/Darcs patch theory**: rejected per the brief's own explicit
  instruction not to adopt without evidence, and no evidence has been
  gathered that justifies the added complexity for hgit's scale.
- **jj's view-snapshot-per-operation model**: not rejected — but it's an
  *operation log* design (see ADR 0006, not yet written), layered on top
  of *some* object storage, not a replacement for the object storage
  question this ADR answers.

## Decision

A repository is **one self-contained, append-only archive file**
(the on-disk realization of the brief's `.HGS` concept), holding
records of the shape already implemented and tested in `Archive.HC`:

```
[U64 length LE][length bytes of content][64-byte BLAKE2b-512 hash]
```

Objects are content-addressed by their BLAKE2b-512 hash (ADR 0004 covers
hash selection specifics). No directory sharding, no separate pack
format at this stage — append-only is the whole story until evidence
(a real corpus, per the brief's benchmarking plan) says otherwise. A
rebuildable index (hash → offset) sits beside or within the archive,
per the brief's "manual, previewable compaction" and "rebuildable index"
requirements — **not yet built** (probe 05 explicitly left this as next
work; this ADR commits to the shape, not the index implementation).

Object *typing* (blob/tree/commit-equivalent) is layered on top of this
generic record format as a type tag in each record's content — **now
implemented and verified** (`src/hgit-core/Object.HC`, FORMAT.md's
"Object typing" section, `experiments/07-object-typing/`): a tag byte
prepended before hashing, confirmed to make identical bytes stored under
different types hash differently. What remains undesigned is the actual
*content* of a tree or commit object (entry lists, parent refs) — the
tagging mechanism itself is done.

## Costs

- No delta compression yet — every version of every object is stored in
  full. Acceptable at M1 scale (per TempleOS's own ~100MB-drive
  philosophy); revisit once a real corpus (per the brief's benchmarking
  plan, doc 06) shows this doesn't hold.
- No sharding means a single large archive file — fine for RedSea's
  contiguous-file model in principle, but "how does an append-only file
  grow under contiguous-only allocation" is still an open question (doc
  01's unresolved risk) that this ADR does not resolve; it commits to a
  format that will need a real answer before real-sized use.
- Rebuilding the index by full linear scan (as probe 05's `ArchiveVerify`
  does) won't scale — needs a real index format before M2.

## What would justify revisiting this

- Corpus benchmarking (doc 06, not yet done) showing full-object storage
  is unacceptably large even at hgit's target scale.
- RedSea's actual contiguous-allocation behavior (still unread from
  source, doc 01) turning out to make in-place archive growth
  impractical, forcing a copy-on-grow or multi-file design.
- A concrete need for partial/streaming access to large objects that a
  single monolithic archive can't serve without loading the whole file.
