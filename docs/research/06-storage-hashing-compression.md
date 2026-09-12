# Storage, hashing, compression

## Experimental evidence

`experiments/02-blake2b-oracle/`: a host-side BLAKE2b reference oracle
(Python `hashlib.blake2b`, a mature standard implementation) verified
against two vectors from primary sources — RFC 7693 Appendix A (unkeyed
BLAKE2b-512 of "abc") and the official BLAKE2 KAT file's first entry
(keyed BLAKE2b-512 of the empty string, key = sequential bytes
`0x00..0x3f`). Both pass. This is the known-good baseline a future
native-HolyC BLAKE2b implementation gets diffed against — it is not
itself hgit's hash implementation.

A near-miss during this: a third vector typed from memory (unkeyed
empty-string hash) was simply wrong (one byte short) — caught
immediately by the oracle failing, not by inspection. Logged in
`failed-approaches.md`. Reinforces the brief's own instruction to
validate against *official* vectors, not recalled ones.

## Experimental evidence — canonical encoding, native HolyC (probe 03)

`experiments/03-canonical-encoding/` + `src/hgit-core/Canon.HC` (first
real hgit-core source file): little-endian `PutU32LE`/`GetU32LE`/
`PutU64LE`/`GetU64LE` written in actual HolyC, pushed over the proven
COM2 channel (probe 01) into real TempleOS, JIT-compiled, executed, and
round-tripped — `PASS canonical_encoding_roundtrip_v2`, verified in the
host-readable serial log. This closes M0's "canonical binary encoding
round-trip, in HolyC" checklist item.

Two real HolyC quirks surfaced and are now documented directly in
`Canon.HC`'s comments (also `failed-approaches.md`): no C-style prefix
typecast (postfix only, `x(Type)`), and a function's declared narrow
return width (`U32`) is not automatically enforced — every accessor here
masks explicitly rather than trusting the type system.

## Experimental evidence — native HolyC BLAKE2b (probe 04)

`experiments/04-blake2b-native/` + `src/hgit-core/Blake2b.HC`: full
BLAKE2b-512 (unkeyed, single-block) implemented in HolyC — IV constants,
SIGMA permutation, compression function, all run natively on real
TempleOS via the proven injection channel. Result matched the RFC 7693
Appendix A vector exactly, on the first push (no debugging round-trip
needed, unlike probe 03) — attributed to applying probe 03's lessons
(generate tables instead of hand-typing, postfix casts, explicit width
masking) proactively rather than rediscovering them. **This closes both
"official BLAKE2b vectors passing in native HolyC" and "same fixture
hashes identically in TempleOS and a host build"** (the host half was
already established by probe 02's oracle computing the identical digest
for the same input).

## Experimental evidence — tiny object archive (probe 05)

`experiments/05-tiny-archive/` + `src/hgit-core/Archive.HC`: a minimal
append-only object archive (`[U64 length][data][64-byte BLAKE2b hash]`
per record) built on `Canon.HC` + `Blake2b.HC`, written to and read back
from a real file on TempleOS (`FileWrite`/`FileRead`, RedSea), with every
record's hash re-verified after the round trip. Closes M0's "append/
read/rebuild of a tiny object archive" checklist item. Found and fixed a
genuine new HolyC quirk along the way (see doc 01 / failed-approaches.md):
bare top-level loops with local declarations can silently misbehave, not
just error, even outside boot phase.

## Experimental evidence — multi-block BLAKE2b streaming (probe 08)

`experiments/08-blake2b-streaming/`: added `B2StreamInit`/
`B2StreamUpdate`/`B2StreamFinal` to `Blake2b.HC` — standard incremental
hashing, no longer capped at one 128-byte block. Verified against a
200-byte and a 300-byte message (2 and 3 BLAKE2b blocks respectively),
matching Python's `hashlib.blake2b` exactly; also verified the same
200-byte message split across three `Update` calls at non-block-aligned
offsets produces the identical digest as one call, specifically
exercising the cross-call buffering logic. A regression check confirmed
the new streaming path agrees with the original `B2Hash512` for `"abc"`.
All four checks passed on the first push.

## Experimental evidence — streaming hash wired into the archive pipeline (probe 09)

`experiments/09-wire-streaming-hash/`: `ArchivePut`/`ArchiveVerify`
(`Archive.HC`) and `HgsPut` (`Hgs.HC`) now call `B2Hash512Any`
(`Blake2b.HC`'s streaming wrapper) instead of the 128-byte-capped
`B2Hash512`. Verified: a 200-byte object stored, written to a real file,
read back, and re-verified alongside a small object — both passed, and
the 200-byte object's hash was cross-checked against probe 08's
independently-verified digest for the same bytes. Real objects larger
than 128 bytes can now actually go through the archive API end to end,
not just through the hash primitive in isolation.

## Not yet done

- `ObjectPut`'s own `tagged[128]` scratch buffer still caps tagged
  objects at 127 content bytes — a separate, smaller limitation than
  the one probe 09 removed (buffer size, not hash capability).
- **Index build** (hash→offset lookup) — probe 05 only verifies records
  linearly; no index structure yet.
- Archive size (currently a fixed ~1KB test buffer) and record count are
  both far below anything real — scaling both up is unverified.
- No compression/chunking work at all — LZ4/zstd-as-reference-only per
  the brief, content-defined chunking corpus, Fossil-style delta corpus.
  Blocked on doc 04's Fossil delta-format read (not yet done) informing
  what a "small auditable native format" should even look like here.
- No RedSea/contiguous-file-storage constraints verified against actual
  kernel source (only the philosophy doc's mention so far, per doc 01).
