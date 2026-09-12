# Probe 02 — BLAKE2b host-side reference oracle

Status: **PASS.** First step of docs/research/06 (storage/hashing).
Establishes a known-good oracle to diff a future native-HolyC BLAKE2b
against, before that native implementation exists — per the brief's own
instruction to have a working baseline before porting.

`oracle.py` checks Python's `hashlib.blake2b` (a mature, standard
implementation) against two vectors from primary sources fetched this
session:

- RFC 7693 Appendix A: unkeyed BLAKE2b-512("abc")
- The official BLAKE2 KAT file's first entry: BLAKE2b-512 keyed with the
  standard sequential-byte key (`0x00..0x3f`), empty input

```
$ python3 oracle.py
PASS abc
PASS kat[0] (keyed, empty input)
```

## Near-miss worth recording

First draft of this oracle used a *third* vector (unkeyed empty-string
BLAKE2b-512) typed from memory. It failed — off by exactly one trailing
byte, a plain transcription slip. Diagnosis was immediate (compare full
strings + lengths) and the fix was simply to drop the untrusted vector
and fetch a real one instead of patching the memory-typed value. Logged
in `docs/research/failed-approaches.md` because it's a good general
reminder: **treat any hash/vector "recalled from memory" as unverified
until fetched from a primary source**, even when it looks right at a
glance (the first 16 hex chars matched).

## Not yet done

- Only 2 of many BLAKE2 KAT vectors checked — fine for "the algorithm and
  the parameter interpretation are right," not exhaustive conformance.
- No native HolyC implementation exists yet to diff against this oracle.
  That's the actual feasibility probe (#2/#3: BLAKE2b in native HolyC,
  same hash on TempleOS and host) — this probe only builds the yardstick.
- BLAKE2b's 64-bit-word operations (the brief specifically flags this as
  worth checking) haven't been evaluated against HolyC's integer types
  yet — HolyC has native U64/I64 (confirmed, doc 01), so no red flags
  expected, but not yet exercised.
