# Probe 04 — BLAKE2b-512 in native HolyC, verified against RFC 7693 on real TempleOS

Status: **PASS, first try.** Closes two more M0 checklist items at once:
"official BLAKE2b vectors passing in native HolyC" and "same fixture
hashes identically in TempleOS and a host build" (the host half was
already established by `experiments/02-blake2b-oracle/`).

## What was done

1. Implemented BLAKE2b-512 (unkeyed, single-block path — inputs that fit
   in one 128-byte block) in HolyC: `B2Rotr`/`B2G`/`B2Compress`/
   `B2Hash512`, plus the IV constants and SIGMA permutation table.
2. Generated the IV/SIGMA table-initialization code with a small Python
   script (`gen_tables.py`) rather than hand-typing 8 hex constants and
   192 permutation indices — the BLAKE2b oracle probe (02) already
   demonstrated how easy manual transcription errors are to make and how
   hard to spot by eye.
3. Applied both HolyC quirks confirmed in probe 03 up front (postfix
   typecasts only; explicit masking at width boundaries) rather than
   discovering them again the hard way.
4. Reused `Canon.HC`'s `GetU64LE`/`PutU64LE` unmodified for the
   byte↔word conversion at the edges of the compression function — first
   real reuse of previously-committed hgit-core code.
5. Booted the same persistent disk from probes 01/03, bootstrapped the
   COM2 daemon (waiting the full ~60s this session's own prior probes
   established was necessary), and pushed the combined
   `Canon.HC + tables + implementation + test driver` (~7.7KB) as one
   chunk.
6. Result, verbatim from the host's `serial.log`:
   ```
   D_OK
   DIGEST:BA80A53F981C4D0D6A2797B69F12F6E94C212F14685AC4B74B12BB6FDBFFA2D17D87C5392AAB792DC252D5DE4533CC9518D38AA8DBF1925AB92386EDD4009923
   D_DONE
   ```
   This is byte-for-byte identical (case aside) to the RFC 7693 Appendix
   A worked example for BLAKE2b-512("abc"), and to the value this
   project's own host-side oracle (probe 02) computes for the same
   input via Python's `hashlib.blake2b`. No debugging round-trip was
   needed this time — it matched on the first push.

## Why "first try" is worth noting, not just reporting

Every other piece of new HolyC written this session (probe 03's
`Canon.HC`) needed at least one QEMU round-trip to fix a real mistake.
This one didn't, and the difference seems attributable to applying
lessons already paid for: generating tables instead of hand-typing them,
using postfix casts from the start, and masking explicitly at every
width boundary as a default habit rather than an afterthought. Recorded
here as a data point for how much the earlier probes' "expensive"
findings are now paying for themselves, not as a claim that HolyC has
gotten any less strict.

## Landed as real hgit-core source

`src/hgit-core/Blake2b.HC` — checked in as the actual algorithm
(`B2Rotr`/`B2G`/`B2Compress`/`B2Hash512`) plus the real, tested
`B2Init()` table-initialization body (not a stub — diffed byte-for-byte
against `tested_source.hc` in this directory before committing, and one
real discrepancy — the file initially committed was missing the
`B2Init();` call inside `B2Hash512` that the tested version had — was
caught by that diff and fixed before commit, not after).

## Not yet done

- **Multi-block streaming.** This only handles messages that fit in one
  128-byte block. hgit will need to hash real objects (source files,
  trees) larger than that — the next concrete step for this area, and a
  materially harder one (running counter across blocks, intermediate
  vs. final compression flag, buffering).
- Only one RFC vector checked (`"abc"`). Should run the keyed KAT vector
  from probe 02 through the native path too before calling this
  conformant, not just "matches one input."
- No `.deb`/general packaging implications yet — this is still
  M0-stage feasibility work, not shipped hgit-core.
