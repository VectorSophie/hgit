# Probe 105 — `ObjectPut`'s own `tagged[4096]` scratch buffer: the real, shared object-content ceiling

Status: **PASS**. Found while investigating why `Offer.HC` silently
skips (or, in the recursive `offertree` path, silently DROPS with no
message at all) any file over 511 bytes (`fsize+1 > 512`,
`OFFER_SKIP file_too_large`): `Offer.HC`'s own `blob_tagged[512]` isn't
actually the deepest limit. `src/hgit-core/Object.HC`'s `ObjectPut` -
called by every real object write in this codebase (blobs, trees,
commits) - had its own separate, smaller-in-spirit-but-actually-larger
`tagged[4096]` fixed stack buffer, a real shared ceiling every caller
inherited silently regardless of its own local caps.

## What was built

`ObjectPut`'s `tagged[4096]` stack array replaced with `MAlloc(dlen+1)`,
freed right after the one `HgsPut` call that needs it - same "no
guessed cap" pattern ADR 0007 already established for `Offer.HC`'s own
`archive` buffer. `HgsPut` itself (checked directly) has no fixed
buffer of its own - it writes straight into the caller-provided
`archive_buf` at `*len`, so this was genuinely the only object-content-
level ceiling in the whole write path.

## Verified

`test_driver.hc` (`P105ObjectPutDynamicTagTest`): a real 10,000-byte
object (a varying byte pattern, not a uniform fill - a truncated or
corrupted copy would actually change the hash, not accidentally still
match) written via `ObjectPut(archive, &alen, OBJ_BLOB, content,
10000)` into a freshly `MAlloc`'d archive buffer. `ObjectPeekType`
correctly reads back `OBJ_BLOB` at the record's start offset, and
`ArchiveVerify` confirms `total=1 ok=1` - the object's stored hash
matches its recomputed hash, round-tripping correctly well past the
old 4095-byte ceiling. `tools/lint-package.sh` clean (only the 3 known
built-in-manifest gaps). Full regression
(`experiments/65-head-deletion/test_driver.hc`) re-run clean
afterward - no existing command's behavior changed for any object at
or under the old size.

## What this does not do

- **Does not by itself let `hgit offer`/`hgit offertree` commit a file
  over 511 bytes.** `Offer.HC`'s own two `blob_tagged[512]` stack
  buffers (one in the flat `HgitOfferWithRelation`, one in the
  recursive `TreeBuildRecursive`) and the flat path's own
  `fsize+1 > 512` skip guard are still in place, unchanged by this
  probe - real, separate follow-up work, not silently left implicit.
  This probe fixes the deeper, shared library-level ceiling
  `Object.HC` itself imposed; `Offer.HC`'s own caller-level caps are a
  distinct fix, deliberately out of scope here.
- Raising `Offer.HC`'s own per-file cap would also require re-deriving
  `ARCHIVE_HEADROOM` (`Offer.HC`'s own fixed 20,000-byte constant,
  computed from the OLD 511-byte-per-file/27-entry worst case) - a
  real, nontrivial follow-on risk (an under-sized `archive` `MAlloc`
  would silently corrupt memory past its capacity, the exact class of
  bug ADR 0007/probes 60-61 already fixed once) that this probe
  deliberately does not attempt to solve in the same slice.
- `Commit.HC`'s own encoding path wasn't specifically re-tested past
  4096 bytes here (only a raw `OBJ_BLOB` via `ObjectPut` directly) -
  it calls the same now-fixed `ObjectPut`, so the same fix applies, but
  a commit-object-shaped test past the old ceiling wasn't run
  specifically.
