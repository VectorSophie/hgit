# Probe 14 — does `FileWrite` handle growing an existing RedSea file?

Status: **PASS.** Resolves a real architectural question raised by
reading `Doc/RedSea.DD` (real TempleOS source, cloned fresh in this
session): *"Files are stored in contiguous blocks and cannot grow in
size."* — a direct, primary-source answer to doc 01's long-standing
"needs confirmation from actual RedSea source" note about the
filesystem constraint hgit's growing archive files would run into.

## Why this mattered right now

Every prior storage probe (05 onward) wrote its `.HGS` file exactly
once per QEMU session, to a fresh filename each time — so none of them
ever actually exercised "grow an existing file already on disk." The
very next CLI commands (`witness`/`offer`) need to append a new object
to a repository `hgit init` already created — i.e., write a *larger*
buffer to a path that already has a smaller file at it. Given RedSea's
confirmed no-growth-in-place behavior, this needed checking before
building on top of the assumption either way.

## What was tested

1. `FileWrite` 16 bytes to `C:/Home/GrowTest.dat`. Read back: correct.
2. `FileWrite` a **different, 64-byte** buffer to the **same path**.
3. Read back again: `size=64`, first byte `100`, last byte `163` — the
   *new*, larger content, not the old 16 bytes or a truncated/corrupted
   mix of both.
4. `PASS filewrite_grows_existing_file`.

## Conclusion

`FileWrite` transparently handles this — most likely by deleting and
recreating the file under the hood, consistent with RedSea's own
no-in-place-growth constraint, but that's an implementation detail
`FileWrite`'s caller doesn't need to think about. **No change needed**
to `hgit-core`'s existing pattern of calling `FileWrite` with a growing
buffer on every save. This was a real risk worth 15 minutes to check
directly rather than assume either way (that it would silently corrupt,
*or* that it would "just work") — it turned out to just work, but that
conclusion is now evidence, not assumption.

## Not yet done

- Only tested a single grow-once case (16→64 bytes). Not tested: many
  repeated grows in sequence (closer to hgit's real usage pattern of
  one `FileWrite` per `offer`), or shrinking a file, or extremely large
  size jumps.
