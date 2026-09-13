# Probe 61 — lifting `Offer.HC`'s `archive[8192]` ceiling (ADR 0007), and a second buffer found doing it

Status: **PASS** — implements and verifies ADR 0007, and finds/fixes
one more real fixed-buffer bug surfaced only once the first was fixed.

## Fix 1: `archive` is now `MAlloc`'d, not a fixed `U8[8192]`

Per `docs/adr/0007-dynamic-archive-buffer.md`: `Offer.HC`'s
`HgitOfferWithRelation` now does `U8 *archive =
MAlloc(rsize + ARCHIVE_HEADROOM)` instead of declaring a fixed
`U8 archive[8192]`, freed before every return. `ARCHIVE_HEADROOM`
(20000) is a real computed worst case given probe 56's own still-in-
place per-offer guards (`tree_content[2048]` caps at ~27 minimal-name
entries, each with up to a 511-byte blob - ~16600 bytes worst case for
one call's new content), not a guess. A much higher
`ARCHIVE_SANITY_MAX` replaces probe 60's own `OFFER_REFUSED` ceiling,
now purely a guard against a corrupted/pathological `rsize`, not real
growth.

First verified `MAlloc`/`Free` themselves work correctly for a buffer
this size (`malloc_probe.hc`): a 20,000-byte buffer written with a
repeating pattern, read back byte-for-byte correct, freed - `MALLOC_PROBE
size=20000 ok=1`.

## Fix 2: a second, different fixed-buffer bug, found by fixing the first

Re-running the exact reproduction that motivated ADR 0007 (30 `hgit
correct` calls in a row on a fresh repo, logging the repo's real file
size before each) with fix 1 in place: growth continued cleanly past
the old 8192-byte crash point... and then crashed anyway, at a larger
scale, with a **different** fault - `RIP:...&PutU64LE+0x0043`
(`evidence/indexbuild-gpf-before-fix.png`). Root-caused without
guessing: `Offer.HC`'s own `old_idx_hashes[64*64]`/`old_idx_offsets[64]`
(built via `IndexBuild` for the parent-tree lookup that carries entity
IDs forward, ADR 0004) is a hardcoded cap of **64 objects in the whole
repo**, not 64 matched files - at ~3 objects per offer (one blob, one
tree, one commit), that's only ~21 offers before overflow. Fix 1 had
been masking this because the *outer* `archive[8192]` ceiling was
always hit first, at a smaller scale (~13 offers); lifting it let real
growth reach this *next* fixed buffer instead.

Fixed the same way as ADR 0007's own pattern: `old_idx_hashes`/
`old_idx_offsets` are now `MAlloc`'d sized from `rcount` (the repo's
own exact object count, already read from the `.HGS` header at this
point in the function - no headroom guess needed, this count is exact
by construction), freed right after their last use in the
parent-tree-lookup block.

## Verified

`test_driver_30_corrections.hc` - same reproduction as before, both
fixes in place: `serial-log-passing-run.txt` shows the repo growing
cleanly and continuously (13447→30808 bytes across this run, continuing
from a prior partial run's own progress before the reboot this probe
needed) through all 30 corrections, `PASS p61_no_ceiling_test`, no
crash, no refusal anywhere. Confirmed the daemon still fully responsive
afterward, and a regression check (a brand-new small repo's ordinary
`init`→`offer`) still works unaffected.

## Not yet done / real remaining risk, explicitly not chased further this session

Per this project's own scope discipline (probe 56/59/60 each fixed
what was found and flagged the rest rather than chasing an unbounded
chain): the **other five** call sites that build a fixed
`idx_hashes[64*64]`/`idx_offsets[64]` pair the same way -
`History.HC`, `HistoryDoc.HC`, `Status.HC`, `See.HC`, and
`ReconcileDoc.HC` (twice) - are the exact same bug, just not yet hit in
this probe's own reproduction (all of them are read-only view/status
commands, not the growth path this probe exercised). **Real,
confirmed-by-code-inspection, not-yet-verified-by-crash risk**: any of
those commands run against a large enough repo will hit the identical
overflow. Flagged here explicitly as the next concrete follow-up,
not fixed in this probe.
