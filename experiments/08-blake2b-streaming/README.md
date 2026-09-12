# Probe 08 — BLAKE2b multi-block streaming, real TempleOS

Status: **PASS, first try, every check.** Removes the single-block
limitation flagged in doc 06/07's "not yet done" — the actual blocker
for hashing anything resembling a real tree or commit object (even two
tiny tree entries exceed 128 bytes).

## What was tested

Standard incremental Init/Update/Final BLAKE2b, added to `Blake2b.HC`
alongside (not replacing) the existing single-block `B2Hash512`:

1. **200-byte message** (2 full blocks + 72 remainder), fed in one
   `B2StreamUpdate` call → digest matched Python's `hashlib.blake2b`
   exactly (`dd82e80e...09e`).
2. **The same 200-byte message, fed via three separate `B2StreamUpdate`
   calls** (90 + 47 + 63 bytes — deliberately not aligned to the
   128-byte block boundary) → produced the **identical** digest as the
   single-call version. This is the part that actually exercises the
   cross-call buffering logic (carrying a partial block across
   `Update` calls, flushing exactly when the buffer fills while more
   data is still coming) — the single-call case alone wouldn't catch a
   buffering bug.
3. **300-byte message** (2 full blocks + 44 remainder) → matched
   Python's oracle exactly (`f98d9610...75b`).
4. **Regression check**: hashed `"abc"` through the new streaming API
   and compared against `B2Hash512("abc")` (already verified against
   RFC 7693 in probe 04) — identical, confirming the new code doesn't
   silently diverge from the already-correct single-block path for
   inputs both can handle.

All four checks passed in the same push, first try — verbatim output:
```
D_OK
digest200:DD82E80EF6E0FACF...CAE09E
split_call_matches_single_call=1
digest300:F98D96100705CED0...B8775B
abc_stream_matches_single=1
D_DONE
```

## Landed as real hgit-core source

Appended to `src/hgit-core/Blake2b.HC` (not a separate file — same
module, same `B2_IV`/`B2_SIGMA`/`B2Compress`/`B2G` machinery, just a new
Init/Update/Final entry point on top). `gen_vectors.py` regenerates the
two ground-truth digests if the test messages ever need to change.

## Not yet done

- Global, single-in-flight-hash state (`b2s_h`/`b2s_buf`/etc.) rather
  than a parameterized context — deliberate for now (ADR 0002 notes
  HolyC struct/class layout isn't verified from source yet), but means
  two hashes can't be computed concurrently/interleaved. Not needed yet;
  flag if a future design requires it.
- No test near BLAKE2b's actual 2^128-bit length-counter boundary
  (meaningless at hgit's realistic scale, not worth simulating).
- This unblocks — but doesn't yet implement — realistic tree/commit
  object content (entry lists, parent refs) that need hashing beyond
  128 bytes. That's the next real step now that the hashing ceiling is
  gone.
