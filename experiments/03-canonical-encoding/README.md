# Probe 03 — canonical encoding round-trip, native HolyC, on real TempleOS

Status: **PASS.** M0 checklist item "canonical binary encoding round-trip,
in HolyC" — done for real, not just planned. Run through the injection
channel proven in probe 01, against the same persistent installed disk
(no reinstall needed — state across QEMU restarts lives on the qcow2
disk; the *daemon*, which is JIT/RAM-only, has to be re-bootstrapped each
boot, which is expected and fine).

## What was done

1. Rebooted `experiments/01-temple-repl`'s disk, this time waiting the
   full ~60s this session's own prior probe determined was necessary
   before typing anything (see `failed-approaches.md`'s "typed too soon"
   entry) — no boot-phase-style errors this time, first try.
2. Bootstrapped the stage-1 COM2 daemon (same as probe 01) — `D_OK`.
3. Pushed a first-draft canonical little-endian encode/decode
   (`PutU32LE`/`GetU32LE`/`PutU64LE`/`GetU64LE`) plus a round-trip
   assertion over COM2. **It failed to compile**: `(U32)buf[off+3]` —
   C-style prefix typecast — errored with `Use PostFix typecast(eg
   'U32')`. Fixed to HolyC's actual syntax, `buf[off+3](U32)`, confirmed
   against `holyc-parser`'s validated corpus
   (`079-expr-expr-postfix-typecast.hc`) rather than guessing again.
4. **It then compiled but FAILed the round-trip assertion.** Pushed a
   diagnostic chunk printing each sub-check and the raw hex of decoded
   values. `chk32=0`, `chk64=1`, `chk32b=0` — the 64-bit path worked, the
   32-bit path didn't. Printed raw hex showed the *correct* low 32 bits
   with garbage in bits 32-51 (`got32=DDF7968676974` — the trailing
   `68676974` is exactly right; the leading `DDF79` is not part of a
   32-bit value at all).
5. **Root-caused and confirmed by experiment, not guesswork**: a function
   declared to return `U32` in this HolyC does not get its result
   truncated/masked to 32 bits on return. Fixed by accumulating into a
   `U64` local and explicitly `& 0xFFFFFFFF` before returning. Pushed the
   fix in isolation first (`fixedchk_a=1 fixedchk_b=1`), then the full
   corrected round-trip: `PASS canonical_encoding_roundtrip_v2`.

## Why this matters beyond "the test passed"

Two newly-confirmed, load-bearing HolyC semantics now feed directly into
`src/hgit-core/Canon.HC` (committed alongside this probe — the first real
hgit-core source file):

- **No prefix typecasts** — postfix only. Cosmetic, but will break naive
  ports of C-shaped code throughout hgit-core.
- **Narrow unsigned return types are not auto-masked.** This is not
  cosmetic — it's exactly the kind of silent-corruption bug a version
  control system's canonical encoding cannot afford. Every fixed-width
  accessor in `Canon.HC` explicitly masks for this reason, with a comment
  pointing back here so it isn't "simplified away" later as redundant.

## Reproduction

See `experiments/01-temple-repl/README.md` for the boot+bootstrap steps
(identical here — same disk, same daemon protocol). The test payload
pushed over COM2 is preserved as `src/hgit-core/Canon.HC` plus the
round-trip assertion shown in this probe's git history.

## Not yet done

- Only tested U32/U64 round-trip on one fixed buffer — no fuzzing, no
  boundary values (0, max), no malformed-input handling yet (that's a
  much later milestone per the brief — "test malformed input at every
  decoder boundary" applies once there's an actual decoder consuming
  untrusted bytes, not a plain encode/decode helper).
- `Canon.HC` has not been run through `holyc-parser`'s lint as a
  pre-flight check — doing so *before* the first push would have caught
  the postfix-typecast mistake without spending a QEMU round trip. Worth
  wiring up before writing more hgit-core source.
