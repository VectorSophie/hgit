# Probe 62 — fixing the remaining `idx_hashes[64*64]` call sites flagged by probe 61

Status: **PASS** — closes the "real, confirmed-by-code-inspection,
not-yet-verified-by-crash risk" probe 61 explicitly flagged: the same
hardcoded 64-object-in-the-whole-repo cap `Offer.HC` had (fixed in
probe 61) also existed in five other call sites - all read-only view/
status commands, not previously exercised at a large enough scale to
crash.

## What was fixed

Same pattern as ADR 0007/probe 61, applied consistently: every
`U8 idx_hashes[64*64]; I64 idx_offsets[64];` pair is now
`MAlloc`'d from `rcount` (the repo's own exact object count, already
read from the `.HGS` header at that point in each function) instead of
a fixed-size stack array, freed on every return path:

- `src/hgit-cli/See.HC` (`HgitSee`) - 4 return paths after allocation,
  each now frees before returning.
- `src/hgit-cli/History.HC` (`HgitHistory`) - 2 return paths inside the
  walk loop, each now frees before returning, plus the normal end.
- `src/hgit-cli/HistoryDoc.HC` (`HgitHistoryDoc`) - only `break`s inside
  its walk loop, one exit path, freed there.
- `src/hgit-cli/Status.HC` (`HgitStatus`) - only one exit path after
  allocation, freed there.
- `src/hgit-cli/ReconcileDoc.HC` - both `HgitReconcileDoc` (2 early
  returns + 1 normal end) and `HgitReconcileOverview` (`break`s only,
  1 exit path) fixed the same way.

Each file was pushed standalone first to confirm a clean compile before
combining, then `Hgit.HC` was re-pushed too (per probe 58's own
documented gotcha - a caller that's already compiled needs
re-pushing for its call sites to pick up a callee's new address, even
with no source changes of its own).

## Verified

Built one real repo, grew it past the old ceiling (26 offers/corrects,
~78 objects - well past the 64-object cap all five of these functions
used to share with `Offer.HC`), then ran **all five affected commands**
against it in the same session: `hgit see`, `hgit history`,
`hgit status`, `hgit historydoc`, `hgit reconcileoverview`. Every one
completed correctly - `serial-log-passing-run.txt` shows `SEE_COMMIT`/
`SEE_RELATION`/`SEE_TREE`/`SEE_END` all correct for the newest commit,
`HISTORY_END shown=26` (the real, full count, not truncated),
`STATUS_UNCHANGED`/`STATUS_END`, and both `DISPATCH_OK historydoc`/
`DISPATCH_OK reconcileoverview` - `PASS p62_all_commands_at_scale`, no
crash anywhere. Confirmed the daemon still fully responsive afterward,
and a normal small-repo regression case still works unaffected.

This closes the very risk-register row probe 61 opened
("confirmed by code inspection, not yet hit by a real crash in any of
these specific call sites") - all five are now both fixed and verified
against a real repo large enough to have crashed them beforehand.
