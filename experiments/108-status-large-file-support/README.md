# Probe 108 — `hgit status`/`statustree`: the same 511-byte-per-file cap, lifted safely

Status: **PASS**. Closes the real, separate limitation surfaced (not
introduced) by probe 107's own test: `hgit statustree` reported
`STATUS_TOO_LARGE_TO_CHECK` for a real nested file over 511 bytes -
`Status.HC`'s own separate `tagged[512]` cap (probe 67), independent
of `Offer.HC`'s (probes 105-107).

## What was built

Both of `Status.HC`'s own per-file hashing sites (the flat `hgit
status` loop, and `StatusTreeWalk`'s own per-directory-level file
branch) had the same shape as `Offer.HC`'s old bug: a fixed
`tagged[512]` stack buffer, guarded by `if (fsize+1 > 512)
STATUS_TOO_LARGE_TO_CHECK` - the file was skipped entirely, with no
NEW/MODIFIED/UNCHANGED classification reported at all, just silence
beyond that one line.

- `tagged` is now `MAlloc`'d at the file's own real size in both
  places, same fix as probes 105-107. A large file now gets a real
  hash and a real classification.
- **A real, separate structural limit remains, and is NOT removed**:
  both sites also buffer full file CONTENT (not just a hash) for
  not-yet-matched candidates, so a later pass can try Fossil's
  fuzzy-similarity rename check (ADR 0009 addendum, probe 84) against
  deleted entries. That buffer (`new_contents`) is a fixed-stride
  array - `disk_count` slots of exactly 512 bytes each - a genuinely
  bigger structural change (a jagged/variable-offset layout, closer to
  the `.HGS` archive's own format) than this probe scopes to fixing.
  Instead: a candidate whose content doesn't fit one slot still gets a
  real hash (for exact-content rename matching, which needs no content
  buffer) and a real NEW/MODIFIED/UNCHANGED report - only the FUZZY
  rename check is skipped for it, via `new_content_lens[ni] = 0`
  (confirmed safe: `FossilSimilarityPercent` returns 0 for a
  zero-length target, checked directly in `Fossil.HC`, never a false
  match).

## Verified

`test_driver.hc` (`P108StatusLargeFileTest`): a real 5,000-byte file,
offered then left unchanged - `STATUS_UNCHANGED` (previously
`STATUS_TOO_LARGE_TO_CHECK`, no classification at all). Same file
edited (still large) - `STATUS_MODIFIED`. That edit committed, then a
genuinely new, unrelated 5,000-byte file added - `STATUS_NEW` (the
`new_contents`-too-large-to-buffer path, confirmed to still correctly
report NEW rather than silently vanishing). The same scenario nested
inside a real subdirectory via `offertree`/`statustree` -
`STATUS_MODIFIED SubA/big.txt`, closing the exact case probe 107's own
test first surfaced.

Rebuilt `packaging/HgitAll.HC`, `tools/lint-package.sh` clean (only
the 3 known built-in-manifest gaps). Both the standing regression and
the full command-surface suite (`tests/full-regression.hc`) re-run
clean afterward.

## What this does not do

- Does not lift `new_contents`'s own fixed 512-byte-per-slot stride -
  fuzzy (edited) rename detection still can't consider a large file as
  either the source or target of a similarity match. Exact-content
  rename detection (no size limit, hash-only) is unaffected. A real,
  separate follow-up if fuzzy detection at this size is ever needed -
  it would need a jagged storage layout, not just a bigger fixed slot.
- `Diff.HC` was checked and confirmed to have no equivalent per-file
  cap of its own (it doesn't do this kind of live-content comparison
  the same way) - nothing to fix there.
