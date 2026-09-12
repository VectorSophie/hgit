# Probe 10 — tree object content, real TempleOS

Status: **PASS, first try.** Designs and verifies the first real object
*content* format — what ADR 0001/FORMAT.md called "not yet designed"
even after object typing (probe 07) landed. Closes that gap for trees;
commit content is the equivalent still-open item.

## Design

A tree's content (the bytes stored under `OBJ_TREE`, after `Object.HC`'s
type tag) is a flat entry list:

```
U32 entry_count
repeated entry_count times:
  U8 name_len
  name_len bytes of name
  U8 child_type   (OBJ_BLOB or OBJ_TREE)
  64 bytes child_hash
```

Deliberately minimal for this probe: flat single-level names (no path
nesting logic here — a real directory tree is built by trees containing
other trees' hashes, recursively, which this format supports but this
probe doesn't yet exercise), linear lookup (no index, consistent with
everywhere else in hgit-core so far).

## What was tested

1. Stored two blob objects (`"hello"`, `"world"`) via `ObjectPut`.
2. Built a tree content buffer with two entries (`"a.txt"` → blob1,
   `"b.txt"` → blob2) — **146 bytes**, deliberately exceeding the *old*
   127-byte `ObjectPut` scratch-buffer cap (confirmed in the test output:
   `tree_content_len=146 (exceeds old 127-byte ObjectPut cap: 1)`).
3. **Bumped `ObjectPut`'s `tagged[]` scratch buffer from 128 to 4096
   bytes** (the fix probe 09 flagged as needed) and verified the tree
   object stores correctly through it.
4. Stored the tree object via `ObjectPut(..., OBJ_TREE, ...)`, wrote the
   whole 3-object archive to a real file, read it back, and re-verified
   all three objects' hashes (`verify_total=3 verify_ok=3`).
5. **Decoded the tree back out of the reloaded file buffer** and looked
   up both entries by name (`TreeFindEntry`) — confirmed each resolves
   to the correct type (`OBJ_BLOB`) and the correct hash, matching the
   blobs' independently-computed hashes exactly
   (`hash_a_match=1 hash_b_match=1`).
6. Final: `PASS tree_object_roundtrip`.

## Landed as real hgit-core source

`src/hgit-core/Tree.HC` (`TreeEncodeEntry`/`TreeFindEntry`, diffed
against this probe's `tested_source.hc` — whitespace-only difference)
and the `ObjectPut` buffer-size bump in `src/hgit-core/Object.HC`
(verified as part of this same test, not separately).

## Not yet done

- **Recursive trees** (a tree entry whose child is itself an `OBJ_TREE`)
  — the format supports it (that's exactly what `child_type` is for),
  but no test has actually built a two-level tree yet.
- **Commit content** — the other object-content design ADR 0001 still
  defers: tree hash + parent hash(es) + metadata (author, message,
  timestamp). Natural next step now that tree content is real.
- Still linear lookup — no index.
- No handling of duplicate names, empty trees, or a name containing
  bytes that would need escaping in some future text rendering (DolDoc
  history views, per the product thesis) — pure binary format only so
  far.
