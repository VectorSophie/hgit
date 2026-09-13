# Probe 89 — nested `OBJ_TREE` objects: the object model already supports it, verified for the first time

Status: **PASS.** Closes `FORMAT.md`'s own long-standing "No
recursive-tree test" note - `hgit-core`'s object model (`Tree.HC`/
`Object.HC`/`Index.HC`) already correctly stores and reads a tree
entry whose child is another tree, using the exact same functions
every real command already calls. **Zero code changes were needed** -
this was a real capability the format's own byte layout reserved since
ADR 0001/0004, just never actually exercised until now.

## What was tested

Built a real two-level object graph entirely with existing,
unmodified functions:

- Two "leaf" blobs (`leaf1.txt`/`leaf2.txt`), stored the same way
  `Offer.HC` stores any real file.
- A **child tree** (the conceptual "subdirectory") holding both leaf
  entries, via `Tree.HC`'s own `TreeEncodeEntry`/`ObjectPut` - no
  different from how any real tree is built today.
- A top-level blob (`top.txt`).
- A **root tree** with two entries: `top.txt` (a normal `OBJ_BLOB`
  entry) and `subdir` (an entry whose `child_type` is **`OBJ_TREE`**,
  its hash pointing at the real child tree object above) - the actual
  thing under test.

All five objects appended to one archive buffer, then read back
through `IndexBuild`/`IndexLookup`/`TreeFindEntry` - the identical
machinery every real hgit command already uses, with no special
"nested tree" handling added anywhere.

## Verified

```
P89_ARCHIVE_LEN=768
P89_OBJECT_COUNT=5
P89_FOUND_SUBDIR=1 type=2
P89_SUBDIR_HASH_MATCHES=1
P89_RESOLVED=1 type=2 len=170 (expect 170)
P89_FOUND_LEAF1=1 hash_matches=1
```

- `TreeFindEntry` on the root tree correctly finds `subdir`, reports
  its type as `2` (`OBJ_TREE`), and its stored hash exactly matches
  the real child tree object's own hash.
- Resolving that hash through the real object index
  (`IndexLookup`) returns a real `OBJ_TREE` record whose content length
  matches exactly what was encoded (170 bytes).
- Calling `TreeFindEntry` **again**, this time on the *resolved child
  tree's own content*, correctly finds `leaf1.txt` inside it, with the
  correct hash - confirming a caller can walk **into** a nested tree
  using the same function recursively, with no new parsing logic
  required at all.

**Regression**: `experiments/65-head-deletion/test_driver.hc` (the
project's full command-surface test) re-run clean immediately after -
this probe is entirely self-contained (in-memory archive, no repo
files touched), so no interference was expected, and none was found.

## What this means

The object *format* has never been the blocker for subdirectory
support - it was designed correctly the first time (ADR 0001/0004) and
just sat unverified. Combined with probe 88's confirmation that real
recursive directory walking is buildable
(`experiments/88-recursive-directory-walk/`), **both real
prerequisites for subdirectory support are now confirmed working**.
What remains is exactly what probe 88's own README already scoped: a
real, separate feature decision to actually wire this into
`Offer.HC` (build nested trees from real nested directories) and every
tree-*consuming* command (`Status.HC`/`Diff.HC`/`Check.HC`/`See.HC`/
`HistoryDoc.HC`/`ReconcileDoc.HC`/`Graph.HC` would all need to walk
recursively, not just one flat entry list) - a real, substantial,
cross-cutting change, deliberately not attempted here.

## Not yet done

- Wiring any of this into a real command - `Offer.HC` still only ever
  builds flat, single-level trees from `FilesFind`'s own non-recursive
  results.
- A real decision on rename/entity-ID semantics across directory moves
  (a file moved between subdirectories) - unexplored.
- `FORMAT.md`'s own "No recursive-tree test" note updated to reflect
  this - the object model itself is verified, but still honestly notes
  no real command builds or consumes a nested tree yet.
