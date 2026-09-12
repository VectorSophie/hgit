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

## Not yet done

- **Multi-block BLAKE2b streaming** — the native implementation only
  handles single-block (≤128 byte) inputs so far. Needed before this can
  hash anything resembling a real hgit object.
- No compression/chunking work at all — LZ4/zstd-as-reference-only per
  the brief, content-defined chunking corpus, Fossil-style delta corpus.
  Blocked on doc 04's Fossil delta-format read (not yet done) informing
  what a "small auditable native format" should even look like here.
- No RedSea/contiguous-file-storage constraints verified against actual
  kernel source (only the philosophy doc's mention so far, per doc 01).
