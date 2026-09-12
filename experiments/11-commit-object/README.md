# Probe 11 — commit object content, real TempleOS

Status: **PASS, first try.** The other object-content design ADR 0001
deferred alongside trees (probe 10). With this, the full object graph
shape a real VCS needs — blob, tree, and commit, each content-addressed
and cross-referencing by hash — exists and works on real TempleOS.

## Design

```
64 bytes  tree_hash
U8        parent_count
repeated parent_count times: 64 bytes parent_hash
U64       timestamp (LE)
U32       message_len (LE)
message_len bytes of message
```

No author/identity field — deliberately deferred, since the product
thesis ties that to "stable entity ID"/"human mark" concepts explicitly
scheduled for M3, not invented ahead of that milestone.

## What was tested

Built a small but real object graph, not just one isolated commit:

1. Two blobs (`"hello"`, `"world"`) → a tree with two named entries
   (reusing probe 10's design directly).
2. **Root commit**: references the tree, `parent_count=0`, message
   `"root commit!"`.
3. **Child commit**: references the *same* tree, `parent_count=1` with
   the root commit's own hash as its parent, message `"child"` —
   exercising the actual point of the design: a commit can name another
   commit as an ancestor by content hash.
4. Wrote all 5 objects (2 blobs + 1 tree + 2 commits) to a real file,
   read it back, and re-verified all 5 hashes
   (`verify_total=5 verify_ok=5`).
5. Decoded the *reloaded* child commit and checked every field against
   independently-known values: tree hash matches, parent count is 1,
   the parent hash matches the root commit's actual computed hash
   (not just "a 64-byte string was stored"), timestamp round-trips
   exactly, and the message decodes correctly.
6. Final: `PASS commit_object_roundtrip`, first push, no retries.

Byte-accounting check, also confirmed in the output: root commit content
= 64+1+0+8+4+13 = **90 bytes** (`c1len=90` ✓); child commit content =
64+1+64+8+4+6 = **147 bytes** (`c2len=147` ✓).

## Landed as real hgit-core source

`src/hgit-core/Commit.HC` (`CommitEncode` + accessors), diffed against
this probe's `tested_source.hc` — blank-line-only differences.

## Not yet done

- Only a two-commit linear chain tested — no merge commits (2+ parents)
  exercised yet, though the format supports `parent_count` > 1 the same
  way it supports 0 or 1.
- No author/identity, no signature, no "human mark" — explicitly
  deferred to M3 per the product thesis, not an oversight here.
- Still no index — same caveat as every prior storage probe.
- This is the object *model*; there's still no `hgit offer`-shaped
  command that actually walks a working directory and builds these
  objects from real files. That's M1 CLI work, not this probe.
