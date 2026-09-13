# Probe 107 — `hgit offertree` (recursive path): the same 511-byte-per-file cap, lifted safely

Status: **PASS**. Closes the follow-up explicitly flagged at the end
of probe 106: `TreeBuildRecursive` (the recursive path behind
`offertree`/`correcttree`/`reverttree`/`reconciletree`) had the SAME
`blob_tagged[512]` cap as the flat path, and - worse - silently
DROPPED an oversized file with no message at all (unlike the flat
path's old `OFFER_SKIP`).

## What was built

- `TreeBuildRecursive`'s per-file `blob_tagged` is now `MAlloc`'d at
  the file's own real size, same fix as probe 106's flat-path version,
  with the `if (fsize+1 <= 512)` guard removed entirely (there was
  never an `else` branch printing a skip message - the file was just
  silently absent from the committed tree).
- **A new recursive sizing helper, `SumTreeFileBytes`**, mirrors
  `TreeBuildRecursive`'s own recursion (same dot/dotdot skip, same
  `attr & 16` subdirectory check) but only sums: every real file's own
  `CDirEntry->size` across the WHOLE subtree under `dir_path`, plus a
  real subdirectory count.
- `HgitOfferTreeWithRelation`'s `archive_cap` is now computed as
  `rsize + new_content_bytes + new_file_count*OBJECT_RECORD_OVERHEAD
  + tree_object_count*(TREE_LEVEL_MAX + OBJECT_RECORD_OVERHEAD) +
  COMMIT_HEADROOM + OBJECT_RECORD_OVERHEAD` - unlike the flat path,
  `offertree` can create MULTIPLE tree objects (one per real
  subdirectory), so the headroom formula scales with
  `tree_object_count` (subdirectory count + 1 for the root tree), each
  bounded by `TREE_LEVEL_MAX` (4096, the largest real per-level tree
  buffer actually used - nested levels use a smaller 2048-byte buffer,
  so 4096 is a safe, real upper bound, not a guess).

## Verified

`test_driver.hc` (`P107OfferTreeLargeFileTest`): a real 6,000-byte
file (varying byte pattern) placed INSIDE a real subdirectory
(`SubA/big.txt`), alongside an ordinary top-level file, offered via
`offertree` - previously this file would have been silently dropped
from the tree entirely, with no error and no evidence anything was
wrong. Now: `DISPATCH_OK offertree`, and `hgit check` afterward
reports `CHECK_OK objects=5` (hash-integrity-verified: 2 blobs + 2
trees + 1 commit - confirming the nested large blob really is a real,
stored, hash-verified object). A second `offertree` with a real edit
to the same large nested file also succeeds (`CHECK_OK objects=10`),
confirming entity-ID/rename continuity still works at this depth past
the old cap too.

**A real, separate, pre-existing limitation surfaced (not introduced)
by this test**: `hgit statustree` reports
`STATUS_TOO_LARGE_TO_CHECK SubA/big.txt` for the same file -
`Status.HC`'s own separate per-file cap (already documented in
`docs/research/failed-approaches.md`, fixed in probe 67 with exactly
this graceful skip message rather than a crash) is untouched by this
probe. Not a regression: this is `Status.HC`'s own already-correct,
already-documented guard doing exactly what it was built to do: report
honestly rather than silently misbehave. A real, separate follow-up if
`status`/`statustree` ever need to compare large files too.

Rebuilt `packaging/HgitAll.HC`, `tools/lint-package.sh` clean (only
the 3 known built-in-manifest gaps). Both the standing regression
(`experiments/65-head-deletion/`) and the full command-surface suite
(`tests/full-regression.hc`) re-run clean afterward (`TFULL_END`
reached, every `CHECK_OK`/`DISPATCH_OK` along the way, no unexpected
failures).

## What this does not do

- `Status.HC`/`Status.HC`-as-used-by-`statustree`'s own separate
  per-file content-comparison cap (see above) - real, separate
  follow-up, not fixed here.
- `TreeBuildRecursive`'s per-directory-level entry-COUNT caps
  (`tree_content[4096]` at the root, `child_tree_content[2048]` one
  level deeper) - unrelated to file byte size, untouched, a real,
  already-documented limit (ADR 0010).
- No test of an even larger file (megabytes+), or of a file large
  enough to also stress `TREE_LEVEL_MAX`'s own headroom margin against
  many real subdirectories at once - 6,000 bytes was enough to prove
  the mechanism past the old 511-byte ceiling and exercise the
  recursive sizing path; further stress-testing not done here.
