# Probe 18 — `hgit offer`, the real recording command, real TempleOS

Status: **PASS, first try.** The integration milestone: every
previously-built piece (canonical encoding, BLAKE2b, the `.HGS` format,
typed objects, tree/commit content, the index, directory enumeration,
the HEAD pointer) combines here into the first command that actually
*records* something, not just reads or scaffolds.

## What `HgitOffer` does

1. Loads the repo's existing object section.
2. Enumerates every file matching `find_mask` (`FilesFind`), reads each,
   stores it as an `OBJ_BLOB`.
3. Builds an `OBJ_TREE` entry list over those blobs (filename, stripped
   of its directory prefix, → blob type + hash).
4. Builds an `OBJ_COMMIT` referencing that tree, with the repo's current
   `HEAD` (if any) as parent, a message, and a timestamp.
5. Appends all new objects, rewrites the `.HGS` file with the updated
   object count, and points `HEAD` at the new commit.

## What was tested

1. Two tiny real files (`OfferFileA.txt`="hello", `OfferFileB.txt`="world")
   on disk, isolated from the dozens of clutter files already on this
   test disk via a distinctive `FilesFind` mask (`"C:/Home/OfferFile*"`)
   rather than a fresh directory (directory creation itself is untested
   — this sidesteps that rather than assuming it works).
2. `HgitInit` a fresh repo, then `HgitOffer` — a **root offering** (no
   prior HEAD). Result: `count=4` (2 blobs + 1 tree + 1 commit),
   `verify_total=4 verify_ok=4` (every object's hash re-verified after
   the rewrite), `head_found1=1` (HEAD correctly set).
3. **Changed one file's content**, then `HgitOffer` again with the same
   mask — a **second offering with a real parent**. Result: `count=8`
   (4 more objects), `verify_total=8 verify_ok=8`, and — the actual
   point of the parent-chain design — `head_changed=1`: HEAD moved from
   the first commit's hash to the second's, confirmed by byte
   comparison, not assumed.
4. Final: `PASS hgit_offer`.

## Why this is the milestone it looks like

Every object created here (both offerings' blobs, trees, and commits)
went through the *exact* accessors/encoders already verified in
isolation across probes 03–17 — this probe didn't re-implement anything,
it composed. The fact that composing eight previously-separate pieces
worked on the first push, with zero debugging, is itself evidence that
the individual pieces were verified honestly rather than "made to pass"
narrowly.

## Landed as real hgit-cli source

`src/hgit-cli/Offer.HC` (`HgitOffer`) — byte-for-byte identical to the
tested version (confirmed via diff, zero differences).

## Not yet done

- **No working-copy diffing** — every matching file is re-blobbed on
  every offer, whether it changed or not (content-addressing still
  deduplicates identical bytes for free at the storage layer, but there's
  no "skip unchanged files" logic at this layer).
- **Fixed-size local buffers** (`archive[8192]`, `tree_content[2048]`,
  per-file `blob_tagged[512]`) — real ceilings, not yet hit by anything
  tested, not yet made dynamic.
- **No self-exclusion** — `find_mask` has to be aimed away from the
  repo's own `.hgs`/`.head` files by the caller; there's no automatic
  "don't offer yourself" logic.
- **`hgit status`'s `STATUS_UNIMPLEMENTED` branch** can now actually be
  built — HEAD, tree-walking, and working-directory listing all exist —
  that's the next concrete step.
- **`hgit history`/`hgit see`** — walking the parent chain from HEAD and
  displaying it — are now straightforwardly buildable on top of this.
