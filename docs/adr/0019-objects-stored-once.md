# ADR 0019 — Objects are stored once; readers tolerate an interrupted write

## Status

**Accepted for 1.9.0** (2026-09-27), working-session review pending.
Applies ADR 0018's scoped exception.

## Context

`ObjectPut` (`Object.HC`) appends unconditionally. `offer` and `offertree`
call it for every blob in the offered tree, so an unchanged file is stored
again on every commit; `merge` does the same for subtrees and conflict
objects. The format never required this: a record is `[U64 len][data][64-byte
BLAKE2b]`, the hash is the object's identity, and every reader already
resolves a hash to its *first* occurrence. Duplicates are wasted bytes with
no meaning. (`hgit-native` mirrored the duplication on purpose so that its
`CHECK_OK objects=N` output matched TempleOS byte for byte.)

Two facts about the existing readers constrain any fix:

1. **The header count is load-bearing on TempleOS.** `Offer.HC`, `Check.HC`,
   `History.HC`, `Merge.HC` and every other archive-reading command allocate
   their index buffers as `MAlloc(rcount*64 + 64)` and
   `MAlloc((rcount+1)*8)`, where `rcount` is the **header's** object count,
   then fill them by scanning the actual records (`IndexBuild`). If the header
   count is smaller than the number of records, the scan overruns the buffer.
   `Check.HC` only *warns* (`CHECK_WARN object_count_mismatch`) when the two
   disagree in either direction.
2. **`IndexBuild` trusts every length field.** It advances by `8 + len + 64`
   without checking the record fits in the file, so a truncated final record
   makes it read past the buffer.

## Decision

### 1. Writers store each object once

When a writer is about to append object `O` (type tag `t`, content `c`), let
`H = BLAKE2b-512(t || c)`. If a record with hash `H` is already in the
archive, **including any record appended earlier in the same command**, the
writer MUST NOT append another. It uses the existing object.

Normative details, so two independent writers produce identical bytes:

- "Already in the archive" means: present in the archive as loaded at the
  start of the command, or appended earlier by this same command. Position is
  first-occurrence.
- Objects that are not skipped are appended in exactly the order the writer
  produced them before this ADR (blobs in enumeration order, then trees
  bottom-up, then the attributes object, then the commit). Skipping removes
  records; it never reorders the rest.
- The header count written by the command MUST equal the number of records
  actually present after the command. It is a count of records, not of
  distinct objects: a legacy archive that already holds duplicates keeps its
  duplicates and its count.
- The rule applies to every object type, including `OBJ_CONFLICT`. Attempting
  the same conflicting merge twice therefore adds the conflict evidence once.

This is a change to **writer behavior only**. Existing archives, with or
without duplicate records, remain valid and readable, and `hgit check`
continues to count every record in `CHECK_OK objects=N`.

### 2. The header count is an upper bound a writer must never under-declare

`FORMAT.md` gains this rule: a reader MUST NOT rely on the header count for
correctness, but TempleOS sizes buffers from it, so **a writer MUST keep
`count >= number of records at every moment the file can be observed**. A
writer that appends records in place MUST raise the count before appending.
After an interruption the count may exceed the records present; `check`
reports `CHECK_WARN object_count_mismatch`, which is harmless.

### 3. A reader stops at the first torn record, not at the first corrupt one

"Torn" and "corrupt" are different failures and a reader treats them
differently.

A record is *torn* when it does not structurally fit: fewer than
`8 + len + 64` bytes remain from its start (equivalently, `RecordEnd`
returns "no fit" for it). This is what an interrupted write produces - the
length and hash fields for the in-flight record are missing or partial, so
there is no full record there to read at all. A reader (`IndexBuild`,
`ArchiveVerify` and every native equivalent) walks records until the end of
the file or the first torn record, and MUST bound-check each length before
advancing. Everything before the first torn record is committed data;
everything from it on is an interrupted write and is ignored. A reader
reports the offset and the number of ignored bytes, and a read-only reader
never truncates. A writer about to append MUST resume from this point (the
consumed length), never from the raw file length, or its new record lands
where no bound-checked reader will ever reach it.

A record is *corrupt* when it fits structurally but its stored hash does not
equal the hash of its data - ordinary bit-rot or media damage deep in an
otherwise well-formed record. A reader does NOT stop at a corrupt record: a
single flipped bit must not hide every record after it. `ArchiveVerifyEx`
keeps walking and counting both `out_total` and `out_ok`, and `hgit check`
reports the difference as `CHECK_FAIL ... corrupt=N` - a diagnostic on
already-committed data, unrelated to `CHECK_WARN torn_tail`, which fires only
on a structural stop.

### 4. No `format_version` bump

`format_version` stays **4**. Sections 1 to 3 change what writers produce and
how tolerant readers are; they do not change the meaning of any existing
byte. A 1.8.9 reader opens a 1.9 archive unchanged. The one visible
difference is that `CHECK_OK objects=N` reports a smaller `N` for a repository
written by a 1.9 writer, because the duplicates are not there.

### 5. Explicit compaction is the only way to remove existing duplicates

Existing archives keep their duplicate records until the user runs an
explicit `compact`, which writes a **new** archive containing every distinct
object exactly once, in first-occurrence order, with an exact header count. It
never removes a distinct object, including dangling ones, so nothing that
`undo`, `redo`, an operation restore or a pending merge can reach is lost.
The original file is left in place until the new one has been fully written
and verified. There is no automatic compaction and no time-based expiry.

## Consequences

- Golden output changes. `tests/full-regression.hc` is re-run on real
  TempleOS after the HolyC change and `fixtures/` is regenerated; the 1.8.9
  fixtures are kept as `fixtures-1.8.9/` so that reading legacy,
  duplicate-laden archives stays under test.
- `hgit-native` keeps a legacy-append mode so byte-exact reproduction of
  1.8.9 output remains a regression test even though the default changes.
- The TempleOS lookup cost drops in proportion to the record count, because
  duplicates never enter the archive; a faster lookup (early-exit comparison,
  then a hash-ordered index) is measured separately, not assumed.

## Alternatives considered

- **Bump to `format_version` 5 to mark "stored once".** Rejected: nothing a
  reader must branch on changed, and the existing policy reserves bumps for
  changes readers can observe. A version number cannot express "this file
  was interrupted", which is the one new hazard, and section 3 handles that
  directly.
- **Deduplicate only in `hgit-native`.** Rejected: the same scenario would
  then print different `CHECK_OK objects=N` on the two implementations, which
  breaks the parity contract this project is built on. The TempleOS writer is
  a small change (15 `ObjectPut` call sites).
- **Compress records or store deltas.** Deferred. The measured overhead is
  duplicate whole objects, not compressibility; that removes 90%+ of the
  bytes by itself. Compression and deltas add recovery cost and semantics
  and need their own evidence.
- **Deduplicate in place on open.** Rejected: rewriting a user's archive as a
  side effect of reading it is the kind of silent change this project avoids.

## What would justify revisiting this

Evidence that distinct objects, not duplicates, dominate stored bytes in real
repositories (large binaries edited in place, many near-identical files)
would justify delta or chunked storage, under a new format version.
