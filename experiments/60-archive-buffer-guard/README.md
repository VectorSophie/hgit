# Probe 60 — root-causing and fixing `Offer.HC`'s `archive[8192]` overflow

Status: **PASS** — closes the last remaining gap probe 56's own
README explicitly flagged as "not yet done": `archive[8192]` (the
whole growing in-memory copy of a repo plus its new objects) had no
bounds check, unlike the two buffers probe 56 already fixed.

## What triggered this

Testing probe 59's own truncation-guard follow-up (running many
`hgit correct` calls in a row to see `ReconcileDoc.HC`'s new bounds
check actually trigger) hit a **different** real crash first, at
around the 13th `correct` in a row on a small, fresh repo - a real
kernel GPF, `RIP:...&CommitEncode+0x0126`
(`evidence/gpf-crash-before-fix.png`), distinct from probe 56's own
GPF (different function, different trigger - no wildcards, no large
files, just many small ordinary corrections in a row).

## Root cause, bisected precisely

Logged the repo's own real file size (`FileRead`'s own `size` out
param) before every `correct` call in a loop. Growth is steady and
exact: **~599-600 bytes per `offer`/`correct`** (one small blob + one
tree object + one commit object, each with its own HGS record
overhead). `Offer.HC`'s `HgitOfferWithRelation` copies the *entire
existing repo* into a fixed `U8 archive[8192]` stack buffer before
adding anything new - once the repo alone (before this call even
starts) exceeds 8192 bytes, that copy loop itself overflows the
buffer. Confirmed exactly: the crash occurred with the repo already at
**8206 bytes** (over `8192` before this call even began copying it).
This is a coarser, whole-repo-scale version of the same bug class
probe 56 fixed at the single-offer scale (`tree_content[2048]`,
`blob_tagged[512]`) - flagged in that probe's own "Not yet done"
section, now confirmed hit in practice, not hypothetical.

## The fix

A guard at the very top of `HgitOfferWithRelation`, right after
reading the existing repo's size: if it's already within 1024 bytes of
`archive`'s own capacity, refuse cleanly (`OFFER_REFUSED
archive_too_large_for_in_memory_buffer size=<n>`) and return without
touching the repo, instead of copying it and corrupting memory.
Deliberately minimal, matching probe 56's own scope discipline: does
not resize the buffer or redesign the storage scheme - a repo that
outgrows 8192 bytes needs a different storage strategy entirely (this
project's own object-store design doesn't require an in-memory
whole-repo copy in principle; `archive[8192]` is an implementation
shortcut from early M1, not part of the `.HGS` format itself), which is
real future architecture work flagged here, not solved by this probe.

## Verified

- **Reproduced the crash first** (not skipped past it): a fresh tiny
  repo, 16 `correct` calls in a row, each call logging the repo's own
  size beforehand - the daemon stopped responding entirely partway
  through iteration 13 (`BEFORE_CORRECT i=13 repo_size=8206` printed,
  nothing after), and a screendump confirmed a real kernel GPF, not a
  hang (`evidence/gpf-crash-before-fix.png`).
- **After the fix**, the identical fresh-repo scenario
  (`test_driver_fresh_bisection.hc`,
  `serial-log-fresh-bisection-full.txt`): the repo grows normally for
  11 real corrections (416→7006 bytes), then at iteration 12
  (`repo_size=7606`, crossing the guard's `8192-1024=7168` margin)
  every subsequent call cleanly prints `OFFER_REFUSED
  archive_too_large_for_in_memory_buffer` and leaves the repo file
  untouched (size stays frozen at 7606 through iteration 15) - no
  crash, `PASS p60c_fresh_bisection_done` at the end.
- **A second, harsher test** (`test_driver_bisection.hc`): 25 `correct`
  calls in a row against a repo that (from an earlier, pre-fix crashed
  attempt) was already sitting at exactly the crash-triggering 8206
  bytes on disk from the start - every single call refused cleanly,
  zero crashes, `PASS p60b_bisection_done`, and the daemon confirmed
  still fully responsive to a follow-up ping afterward.
- **Regression check**: a brand-new, small repo's normal `init`→
  `offer` still works completely unaffected (`PASS
  p60d_normal_offer_regression`).

## Not yet done

- The 8192-byte in-memory ceiling itself isn't lifted - a real repo
  that needs to grow past it (a legitimate, expected outcome of normal
  use, not an edge case) currently just stops accepting new offers
  cleanly rather than working. Redesigning `Offer.HC` to avoid needing
  a whole-repo copy in memory at all (e.g. appending new objects
  directly to the file, matching how `Archive.HC`'s own on-disk format
  already supports incremental append) is real, concrete follow-up
  work - flagged here, not attempted in this probe.
- The exact 1024-byte headroom margin is a heuristic, not a proven
  bound (same honest caveat as probe 56's own margins) - a single
  `offer` with several files near the per-file size cap could still
  need more than 1024 bytes of headroom.
