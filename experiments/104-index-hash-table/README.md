# Probe 104 — a real hash table for `Index.HC`, built and verified standalone

Status: **PASS** — closes `docs/research/06-storage-hashing-compression.md`'s
long-standing "Not yet done" item, "a real hash table for the index".

## What was built

`src/hgit-core/Index.HC` gains `IndexHashTableSize`/`IndexBuildHashTable`/
`IndexLookupHashTable` - open addressing with linear probing over the
same `index_hashes`/`index_offsets` arrays `IndexBuild` already fills.
Hashed on the first 8 bytes of the stored (BLAKE2b-derived, already
near-uniform) hash - no need for a stronger mix, since a collision
just costs one extra probe step either way. Caller picks a table size
(`IndexHashTableSize` suggests `count*2 + 1`) and `MAlloc`s it, matching
every other dynamic buffer in this codebase since ADR 0007 - this file
doesn't own that memory.

**Deliberately NOT wired into any real command yet.** All six existing
`IndexLookup` call sites (`Offer.HC` x3, `History.HC`, `Check.HC`,
`ReconcileDoc.HC` [and `See.HC`/`Status.HC` where they build an index])
still use the linear scan. Same "build and verify standalone before
adopting" pattern this project already used for `Fossil.HC` (ADR
0008): no real evidence yet that hgit's current real scale (low
hundreds of objects per repo, per ADR 0013's own note) makes the
linear scan a practical bottleneck. Adopting it into real call sites
without that evidence would be exactly the kind of premature
completeness ADR 0007's own "no guessed cap" lesson argues against.

## Verified

`test_driver.hc` (`P104IndexHashTableTest`): builds a real repo via 25
real offers, each with genuinely distinct content (`"content number
N"`) so every offer creates a real new blob object rather than a
content-addressed dedup hit - 75 real objects total
(`P104_OBJECT_COUNT=75`). Builds both the existing linear index and
the new hash table over the SAME real `index_hashes`/`index_offsets`
arrays IndexBuild produced from the real `.HGS` file, then:

- Looks up every one of the 75 real stored hashes both ways - all 75
  agree on the exact same byte offset (`P104_REAL_HASH_MISMATCHES=0`).
- Looks up two fabricated, definitely-absent hashes (all-zero,
  all-`0xFF`) - both lookup paths agree "not found" for both
  (`P104_ABSENT_ZERO_AGREE=1`, `P104_ABSENT_FF_AGREE=1`).

`PASS p104_index_hash_table_equivalence` — real output, captured in
`serial-log-evidence.txt`. `tools/lint-package.sh` clean (only the 3
known built-in-manifest gaps). Full regression
(`experiments/65-head-deletion/test_driver.hc`) re-run clean
afterward, no source behavior change for any existing command.

## Not yet done

- Not wired into any real call site (see above) - a separate, later
  decision if real corpus growth ever makes the linear scan a measured
  bottleneck, not assumed here.
- No real performance benchmark comparing the two (object counts here
  are low enough that timing either would be noise, not signal) - this
  probe verifies CORRECTNESS/equivalence, not a measured speedup.
- Collision behavior under a much larger, adversarially-clustered
  corpus (many hashes sharing the same first 8 bytes) untested - not a
  real scenario BLAKE2b's own uniform output makes likely, but not
  proven safe at scale either.
