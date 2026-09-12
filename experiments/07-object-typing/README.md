# Probe 07 — object typing (blob/tree/commit-equivalent), real TempleOS

Status: **PASS, first try.** Implements the "object typing" work ADR
0001 explicitly deferred, and FORMAT.md flagged as "not yet designed."

## Design

A single type-tag byte (`OBJ_BLOB=1`, `OBJ_TREE=2`, `OBJ_COMMIT=3`) is
prepended to an object's content *before* hashing and storing — matching
Git's own approach of hashing `"<type> <size>\0<content>"` rather than
bare content, and specifically chosen so that **identical bytes stored
as different types get different content addresses** (a tree and a blob
that happen to contain the same bytes must not collide).

## What was tested

1. Stored three tagged objects (a 5-byte blob, 3-byte tree, 4-byte
   commit) into a `.HGS`-formatted archive (header + records).
2. Read back each record's type tag directly from the buffer —
   `type_blob=1 type_tree=2 type_commit=3`, all correct.
3. **The actual point of the design**: hashed the same 3 bytes (`"TRE"`)
   once tagged as `OBJ_BLOB` and once as `OBJ_TREE` — confirmed the two
   hashes differ (`same_bytes_diff_type_differ=1`). Without this, a tree
   and a blob with coincidentally identical bytes would be
   indistinguishable at the content-address level, silently breaking
   the "everything is content-addressed" premise from ADR 0001.
4. Round-tripped the whole thing through the real filesystem
   (`FileWrite`/`FileRead`) and re-verified all three records' hashes via
   `Archive.HC`'s existing `ArchiveVerify` — `reload: hok=1 count=3
   verify_total=3 verify_ok=3`.
5. Final: `PASS object_typing`.

## Landed as real hgit-core source

`src/hgit-core/Object.HC` — `ObjectPut`/`ObjectPeekType`, diffed against
this probe's `tested_source.hc` before committing (comment-only
difference).

## Not yet done

- Only three hardcoded tiny objects tested — no real tree structure
  (parent→child entries) or commit structure (tree ref + parent refs +
  metadata) has been designed yet. This probe proves the *tagging*
  mechanism works, not a full object graph.
- `ObjectPeekType` requires the caller to already know the record's
  offset (returned by the corresponding `ObjectPut`/`HgsPut` call) —
  there's no lookup-by-hash yet (still blocked on the index, per
  ADR 0001's "costs").
- No malformed-input handling (an unrecognized type byte, a truncated
  record) — same gap FORMAT.md already flags for `HgsReadHeader`.
