# ADR 0007 — Replace `Offer.HC`'s fixed `archive[8192]` with a dynamically sized `MAlloc` buffer

## Status

**Implemented and verified** (`experiments/61-dynamic-archive/`, PASS).
`archive` is `MAlloc`'d instead of a fixed `U8[8192]`; a 30-correction
test that previously crashed at the 13th call now completes cleanly
with the repo grown to 30,808 bytes, no refusal, no corruption. Also
found and fixed one more real fixed-buffer bug in the same
investigation: `old_idx_hashes`/`old_idx_offsets` (a hardcoded 64-object
cap, unrelated to `archive`) overflowed once this ADR's own fix lifted
the earlier ceiling and let real growth continue - fixed the same way
(`MAlloc`'d from the repo's own exact object count). See that probe's
README for the full account of both fixes and how the second was
found.

The same `idx_hashes[64*64]`/`idx_offsets[64]` pattern also existed in
five other call sites (`History.HC`, `HistoryDoc.HC`, `Status.HC`,
`See.HC`, `ReconcileDoc.HC` twice) - fixed identically and verified
against a real 26-offer/~78-object repo in
`experiments/62-index-buffer-sweep/` (PASS).

## Context

`docs/adr/0001-repository-model.md`'s object-store design never
required a whole-repo in-memory copy - `.HGS` is a plain append-only
record format (`FORMAT.md`, `src/hgit-core/Archive.HC`/`Hgs.HC`).
`Offer.HC`'s `HgitOfferWithRelation` reads an existing repo, copies its
entire object section into a **fixed** `U8 archive[8192]` stack buffer,
appends the new blob(s)/tree/commit to that same buffer, then
`FileWrite`s the whole thing back - an implementation shortcut from
early M1, not a property of the on-disk format itself.

Probe 60 (`experiments/60-archive-buffer-guard/`) found and fixed a
real, reproducible kernel GPF: a repo that simply accumulates ~13
ordinary offers (no wildcards, no large files - each offer/correct
grows the repo by ~600 bytes) exceeds 8192 bytes and overflows this
buffer. That probe's fix was a clean refusal
(`OFFER_REFUSED archive_too_large_for_in_memory_buffer`) rather than a
crash - a real, honest improvement, but it leaves the underlying
ceiling in place: a repo that legitimately needs to grow past 8192
bytes (an entirely normal outcome of ordinary use, not an edge case)
simply stops accepting new offers. That probe's own README flagged
lifting the ceiling as real follow-up architecture work, not attempted
there.

## Alternatives considered

- **Bump the fixed buffer to a bigger constant** (e.g. 65536): rejected
  as not actually solving the problem, only moving the same ceiling
  further out - any fixed size is eventually wrong for a real repo that
  keeps growing, and this project's own philosophy (per ADR 0003's
  `Meta.HC` precedent) is to fix a scaling problem at its root rather
  than pick a bigger arbitrary constant.
- **Redesign the on-disk format for true incremental append**
  (`FileWrite` a small delta at the end of the existing file, rewriting
  only the 16-byte header in place, never reading the whole object
  section into memory at all): the more thorough fix, and arguably the
  "correct" one long-term, but a much bigger change - it would need new
  primitives for "append N bytes to an existing file starting at a
  known offset" and "rewrite just the header," neither built nor
  verified. Rejected *for this ADR's scope* as premature: probe 60's
  own bisection shows real repos are nowhere near large enough yet to
  need it, and this project's standing "no premature optimization"
  stance (already applied to `Index.HC`'s and `Meta.HC`'s own linear
  scans) argues for the smaller fix now, revisiting this alternative if
  real usage ever needs it.
- **Dynamically size the same in-memory buffer with `MAlloc`** (this
  ADR's choice): keeps every existing call site, format, and function
  signature in `Offer.HC` unchanged - `archive` is still one
  contiguous buffer built the same way, just heap-allocated at the size
  this call actually needs (`rsize` plus a generous, still-bounded
  headroom for the new content) instead of a fixed stack array. Removes
  the artificial ceiling entirely (bounded only by available heap
  memory, not an arbitrary constant) with a minimal, low-risk diff.
  `MAlloc`/`Free` are real, confirmed-working TempleOS kernel
  primitives (verified directly in this session,
  `experiments/61-dynamic-archive/` - a 20,000-byte buffer written,
  read back, and freed with no corruption) - not a new dependency this
  project hasn't already implicitly relied on (the daemon's own
  bootstrap uses `MAlloc` for its receive buffer).

## Decision

`Offer.HC`'s `HgitOfferWithRelation` replaces `U8 archive[8192]` with
`U8 *archive = MAlloc(rsize + ARCHIVE_HEADROOM)` (a named constant,
generous enough for one call's worth of new objects - see probe 56's
own per-file/tree caps, which already bound a single call's new
content), and `Free(archive)` before returning on every path. Probe
60's `OFFER_REFUSED` guard is replaced by a much higher, purely
sanity-level ceiling (protecting against a truly pathological
`rsize`, e.g. a corrupted or absurdly large file, not real growth) -
real ordinary growth no longer hits any refusal at all.

## What this slice does not do

- Does not change the on-disk `.HGS` format at all (`FORMAT.md`
  unchanged) - this is purely an in-memory implementation detail of
  `Offer.HC`.
- Does not add incremental/partial-file append (see "Alternatives
  considered" above) - still reads and rewrites the whole file each
  offer, just without an artificial in-memory size ceiling.
- Does not touch `HistoryDoc.HC`/`ReconcileDoc.HC`/`See.HC`, which read
  (not modify) a repo into their own fixed buffers for building
  human-facing documents - a different, lower-priority risk (probe 59
  already added a heuristic guard to `ReconcileDoc.HC`'s own buffer;
  those read-only views are not the load-bearing growth path a repo's
  entire real object history has to survive).

## Costs

- One more `MAlloc`/`Free` pair per `offer`/`correct`/`revert`/
  `reconcile` call - real but small overhead, and this project already
  accepts "no premature optimization" per `Index.HC`'s own precedent.
- `MAlloc` failure (out of memory) isn't itself handled distinctly here
  - a `NULL` return would need its own check, real follow-up if it ever
  matters in practice; not exercised in this ADR's own verification.

## What would justify revisiting this

- If real usage shows repos growing large enough, often enough, that
  a full read-modify-rewrite-whole-file cycle (not just the in-memory
  buffer size) becomes the actual bottleneck - that's when the
  "true incremental append" alternative above becomes worth building.
