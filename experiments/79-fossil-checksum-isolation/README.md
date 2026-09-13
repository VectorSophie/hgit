# Probe 77 — narrowing ADR 0008's Fossil.HC bug further: it's in the encode side, and needs the full call-nesting

Status: **Narrowed further, still not root-caused.** Three real
hypotheses tested and ruled out; one real, decisive new fact found:
the wrong checksum is already wrong at the moment `FossilChecksum`
returns *inside the encoder* (`FossilDeltaMakeTrivial`), not in
`FossilDeltaApply`'s own decode/verify logic - and it does **not**
reproduce when `FossilChecksum` is called directly, bypassing
`FossilDeltaMakeTrivial` entirely.

## Hypotheses tested and ruled out

1. **Mixed-signedness comparison** (`FossilDeltaApply`'s trailer check
   compared an `I64 declared_checksum` against a `U64`-masked
   `real_checksum`): changed to compare `U32`-vs-`U32`
   (`declared_checksum32`) - the known-failing reproduction
   (`test_driver_failing_extra_locals.hc`) still failed identically.
   Ruled out. (Kept as a harmless type-clarity improvement in
   `Fossil.HC` regardless - see the file's own comment.)
2. **Stack-buffer overlap** (`delta[512]`/`reconstructed[512]` as
   stack arrays, sensitive to the caller's own stack-frame shape):
   moved both to `MAlloc`'d heap buffers (`p77_heap_bufs.hc`) - still
   failed (`HEAPBUF_APPLY_OK=0`). Ruled out.
3. **An intermediate `Bool ok` local for the call's return value**:
   removed it, printing `FossilDeltaApply(...)`'s return value
   directly inline (`p77b_inline_result.hc`, still with heap buffers)
   - still failed (`INLINE_APPLY_OK=0`). Ruled out.

## The real new fact: the bug is in the encoder, not the decoder

Temporarily instrumenting both functions (`CommPrint` right after each
computes its own checksum) and re-running
`test_driver_failing_extra_locals.hc`'s exact known-failing shape:

```
FDMT_DEBUG sum=1278475355                                  <- FossilDeltaMakeTrivial's own encode-time checksum
FDA_DEBUG tlen=28 declared_target_len=28                    <- reconstructed length is correct
FDA_DEBUG declared_checksum32=1278475355 real_checksum=1127349339   <- decode-time re-checksum of the SAME reconstructed bytes
BISECT_APPLY_OK=0
```

`real_checksum` (computed by `FossilDeltaApply` re-hashing the
reconstructed bytes) is `1127349339` - the correct value (matches
`enc_check=1127349339` from the known-passing configuration
elsewhere). `FDMT_DEBUG sum=1278475355` shows the *encoder* already
computed and stored the *wrong* checksum, before the delta even left
`FossilDeltaMakeTrivial`. This rules out any theory located in
`FossilDeltaApply`'s own decode/compare logic (the checksum comparison
fix in hypothesis 1, the target-length check, `FossilGetInt`'s own
decoding) - the corruption happens earlier, on the encode side, in
`FossilChecksum(target, target_len)`'s own return value as observed by
its caller `FossilDeltaMakeTrivial`.

## But it does NOT reproduce calling `FossilChecksum` directly

`p77c_checksum_isolated.hc` calls `FossilChecksum` directly on the
exact same fixed string, from two functions - one with the exact
extra-locals shape known to trigger the bug through the full delta
path, one minimal:

```
CHECKSUM_FAILING_SHAPE=1261698139
CHECKSUM_MINIMAL_SHAPE=1261698139
```

Identical, correct in both. So the bug is **not** "FossilChecksum
misbehaves based on its own direct caller's shape" - it specifically
needs the extra call-nesting layer through `FossilDeltaMakeTrivial`
(test driver -> `FossilDeltaMakeTrivial` -> `FossilChecksum`), not just
(test driver -> `FossilChecksum`) directly. Whatever's happening
depends on `FossilDeltaMakeTrivial`'s own local state/stack shape (it
has its own locals: `len`, `i`, `sum`) interacting with its *caller's*
extra locals, in a way that corrupts what `FossilChecksum` computes or
returns from *inside* that specific call site - not a property of
`FossilChecksum` as a standalone function.

## Where this leaves ADR 0008

A more precise characterization than before: the bug requires (a) an
extra, unrelated local declared in the outermost caller, AND (b) at
least one intermediate function-call layer between that caller and
`FossilChecksum`. Calling `FossilChecksum` directly from the
shape-sensitive caller does not trigger it. This is real, additional
narrowing - not a fix, and not a root cause. `experiments/76-compiler-source-access/`'s
own finding (TempleOS's compiler source is readable at
`D:/Compiler/*.HC.Z`) remains the concrete path to actually finishing
this - tracing `FossilDeltaMakeTrivial`'s own compiled intermediate
code through `OptPass012`/later passes is the next real step, not
attempted in this probe (a substantial task, honestly not started
here).

## Not yet done

- The actual compiler-internals trace (see above).
- Whether the bug reproduces with a *different* two-level nesting
  (not `FossilDeltaMakeTrivial` specifically) - not tested; would tell
  us whether it's specific to that function or "any two-level nesting."
