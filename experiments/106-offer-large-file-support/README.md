# Probe 106 — `hgit offer` (flat path): the real 511-byte-per-file cap, lifted safely

Status: **PASS**. Follow-up to probe 105, which fixed `ObjectPut`'s
own shared `tagged[4096]` ceiling but deliberately left `Offer.HC`'s
own caller-level `fsize+1 > 512` skip guard in place - this probe does
that remaining fix, for the flat `hgit offer` command only.

## What was built

`Offer.HC`'s `HgitOfferWithRelation` (the flat, non-recursive `hgit
offer`/`correct`/`revert`/`reconcile` path):

- The per-file `fsize+1 > 512` skip (`OFFER_SKIP file_too_large`) is
  gone. Each matched file's own blob-hashing scratch buffer
  (`blob_tagged`) is now `MAlloc`'d at exactly `fsize+1` instead of a
  fixed `[512]` stack array, same pattern probe 105 used for
  `ObjectPut` itself.
- **`archive`'s own capacity is now a real, computed sum, not a fixed
  headroom.** Simply widening `blob_tagged` without also fixing this
  would have reintroduced exactly the class of bug ADR 0007/probes
  60-61 already fixed once: `ARCHIVE_HEADROOM` (a fixed 20,000-byte
  constant) was derived from the OLD worst case (up to 27 small files
  at 511 bytes each) - a single large file could silently overflow
  `archive`'s `MAlloc`, corrupting adjacent heap memory. Instead, a
  first `FilesFind` pass over the same `find_mask` sums every matched
  entry's own real `CDirEntry->size` field (no `FileRead` needed just
  to size - confirmed real via `Kernel/BlkDev/FileSysFAT.HC`'s own
  `tmpde->size=de->size`), and `archive_cap` is computed as
  `rsize + new_content_bytes + new_file_count*OBJECT_RECORD_OVERHEAD
  + TREE_COMMIT_HEADROOM` - a real worst case for THIS call, not a
  fixed guess. `ARCHIVE_SANITY_MAX` still guards the total against a
  pathological/corrupted size.

## Deliberately out of scope (same "flat first" pattern as ADR 0010/0011)

`HgitOfferTreeWithRelation` (`offertree`, the recursive path) and its
own `TreeBuildRecursive` still have the OLD `blob_tagged[512]` cap and
the OLD fixed `ARCHIVE_HEADROOM` - untouched here, a real, separate
follow-up. Notably, `offertree`'s own large-file case is currently
worse than the flat path's old behavior: `TreeBuildRecursive` silently
DROPS an oversized file from the tree with no message at all (no
`OFFER_SKIP`-equivalent print), unlike the flat path which at least
printed one. Not fixed in this slice - flagged explicitly so it isn't
mistaken for already resolved.

`tree_content[2048]`'s own entry-COUNT cap (unrelated to file byte
size) is untouched - a real, separate, already-documented limit.

## Verified

`test_driver.hc` (`P106LargeFileOfferTest`): a real 5,000-byte file
(a varying byte pattern, not uniform) offered into a fresh repo -
previously this would have hit `OFFER_SKIP file_too_large`; now it
succeeds (`DISPATCH_OK offer`, no skip). `hgit check` afterward
reports `CHECK_OK objects=3` (blob+tree+commit, hash-integrity-
verified) with no referential or dangling problems. A second offer
with a real edit to the same large file (tests entity-ID/rename-
continuity machinery still works past the old cap) also succeeds
cleanly (`CHECK_OK objects=6`), and a small file offered into the same
repo afterward still works too (`CHECK_OK objects=9`) - the fix didn't
regress the ordinary small-file path. Real serial-log evidence in
`serial-log-evidence.txt` (a first run accidentally called `hgit see`
without its required commit-hex argument, producing a harmless,
unrelated `DISPATCH_ERR bad_hash` from a test-driver mistake, not a
real bug - corrected and re-run clean, the log kept here is the
corrected run).

`tools/lint-package.sh` clean (only the 3 known built-in-manifest
gaps - now 23 occurrences instead of 21, the expected +2 from this
probe's own new `FilesFind`/`DirTreeDel` sizing pre-pass). Both the
standing regression (`experiments/65-head-deletion/test_driver.hc`)
and the full command-surface suite (`tests/full-regression.hc`,
covering offer/offertree/merge/export/import/help and more) re-run
clean afterward (`TFULL_END` reached with every `CHECK_OK`/
`DISPATCH_OK` along the way).

## What this does not do

- `offertree`'s own large-file cap (see above) - real, separate
  follow-up.
- No real benchmark of the sizing pre-pass's own cost (a second
  `FilesFind` call per offer) - at hgit's current real scale
  (low hundreds of objects, small match counts) this is not expected
  to matter, not measured here.
- No test of a truly enormous file (megabytes+) - 5,000 bytes was
  enough to prove the mechanism past the old 511-byte ceiling; real
  practical limits at much larger sizes (TempleOS's own RedSea
  filesystem constraints, real `MAlloc` limits) remain unexplored.
