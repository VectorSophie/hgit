# Probe 80 — ADR 0008's Fossil.HC bug: real root cause found and fixed

Status: **RESOLVED.** Closes the "caller-shape-sensitivity" mystery
that ADR 0008 left open since probe 68, narrowed further in probes 77
and 79. Every previously-failing reproduction in
`experiments/68-fossil-delta-format/` now passes.

## The real root cause

`FossilChecksum`'s original implementation cast each raw byte read to
`(U64)` and immediately shifted it left, composing four such casts
into one word with `|`:

```c
U64 word = (data[pos](U64) << 24) | (data[pos+1](U64) << 16) |
           (data[pos+2](U64) << 8) | data[pos+3](U64);
```

**A `(U64)` cast on a raw byte read does not reliably zero-extend once
its result is shifted and composed with other similarly-cast values in
the same expression.** Stray garbage bits above bit 7 - left over from
whatever previously occupied that register/stack slot, which is
exactly why this varied by caller shape (more/different locals shift
what's "left over") - leak into the final sum. `experiments/68`'s own
original quirk verification (probe 68) never caught this: it printed
one clean byte value in isolation, which looks correct even with
garbage sitting above bit 7 - it only corrupts a *composed*
multi-byte-cast expression like this one.

**Independently verified with ground truth**: computed
`FossilChecksum`'s expected result for a real 28-byte string by hand
in Python (`total: 1432286299`, `test_ground_truth_minimal.hc`'s own
docstring). The unfixed function, in its most minimal possible caller
(no extra locals, no nesting at all), returned `1127480411` -
already wrong even in the "baseline" case, not just the previously-
suspected "extra locals" shapes. Replicating the exact same byte-read/
shift/OR arithmetic *inline* in the test function itself (bypassing
`FossilChecksum` as a separate function entirely,
`test_inline_arithmetic_unmasked.hc`) reproduced the same class of
wrong per-word values, ruling out anything specific to how
`FossilChecksum` itself gets compiled as a function - this is a
property of the *expression pattern*, not of that one function.

## The fix

Explicitly `& 0xFF` each byte immediately after its `(U64)` cast,
before shifting:

```c
U64 word = ((data[pos](U64) & 0xFF) << 24) | ((data[pos+1](U64) & 0xFF) << 16) |
           ((data[pos+2](U64) & 0xFF) << 8) | (data[pos+3](U64) & 0xFF);
```

`test_inline_arithmetic_masked_FIX.hc` confirms this produces every
per-word value and the final sum *exactly* matching the independently
computed ground truth (`1432286299`), where the unmasked version
matched nothing.

## Why `Canon.HC`'s `GetU32LE` was never affected

Given how foundational `GetU32LE`/`GetU64LE` are (every hash, length,
and offset in hgit's own object format goes through them), this needed
checking directly rather than assumed safe:
`test_getu32le_sanity_check.hc` confirms `GetU32LE` returns the
correct, expected value (`0x44332211` = `1144201745`) both in a
minimal shape and with the same "extra locals" shape known to trigger
`FossilChecksum`'s bug. `GetU32LE`'s own byte composition is
structurally different in one key way: only **one** of its four terms
carries an explicit `(U64)` cast (`buf[off+3](U64) << 24` - the
highest, most-significant byte); the other three are used uncast. The
refined characterization: **multiple explicit `(U64)` casts of raw
byte reads composed together in one shifted-OR expression is what
triggers the garbage-leak; a single explicit cast combined with
implicitly-typed terms (as `GetU32LE` already happened to do) is
safe.** `Canon.HC`'s own code was never at risk - this was a real,
lucky asymmetry in how it was originally written, now understood
rather than just observed to work.

`GetU64LE` was also spot-checked directly (a real 8-byte little-endian
value, `0x8877665544332211`, correctly returned as the matching signed
`I64` bit pattern, in both a minimal and an extra-locals shape) - its
own loop-based composition (`v |= buf[off+i](U64) << (i*8)` as a
separate statement per iteration, not one single expression with
multiple casts) is a third safe pattern, for a different structural
reason than `GetU32LE`'s single-cast approach.

## Verification: every original bisection reproduction now passes

Re-ran every file in `experiments/68-fossil-delta-format/` against the
fixed `Fossil.HC` (full evidence in `serial-log-full-evidence.txt`):

- `test_driver_failing_extra_locals.hc`: `BISECT_APPLY_OK=1` (was `0`)
- `test_fails_unrelated_function_call.hc`: `STRLENCALL_APPLY_OK=1` (was `0`)
- `test_fails_one_i64_local.hc`: `ONLYI64_APPLY_OK=1` (was `0`)
- `test_fails_one_u32_local.hc`: `U32EXTRA_APPLY_OK=1` (was `0`)
- `test_fails_unused_checksum_call.hc`: `EXTRACALL_APPLY_OK=1` (was `0`)
- `test_fails_used_plain_local.hc`: no longer fails
- `test_ruled_out_name_collision.hc`: `NAMECOLLISION_APPLY_OK=1` (was `0`)
- `test_driver_passing_minimal.hc` / `test_PASSES_used_checksum_call.hc`:
  `enc_check`/`dec_check` now both `1432286299` - the real, ground-
  truth-verified value (previously these "passed" only in the narrow
  sense that two wrong values happened to match each other, e.g.
  `1127349339`, never the mathematically correct checksum).
- `test_driver_original.hc`: a deliberately corrupted delta still
  correctly reports `CORRUPT_APPLY_OK=0` - the fix doesn't disable the
  checksum as an integrity check, it makes it *correct*.

**Regression**: re-ran `experiments/65-head-deletion/test_driver.hc`
(the project's standing full command-surface regression) - all still
correct.

`tools/lint-package.sh` not re-run for this file specifically since
`Fossil.HC` isn't in `tools/build-package.sh`'s own concatenation list
- pushed and compiled standalone against the live daemon, same as
every prior Fossil.HC probe.

## What this means for ADR 0008

The reliability gap that blocked adoption is closed:
`FossilChecksum` is now correct, verified against independently
computed ground truth, across every previously-failing caller shape.
`Fossil.HC` is still **not** wired into `tools/build-package.sh` -
not because of the reliability question anymore, but because
`FossilDeltaMakeTrivial` remains a one-literal-segment encoder with no
real diff algorithm (no compression value on its own), and no real
hgit command currently needs delta compression at all. Adopting it
into the build now would add real dependency-graph weight for zero
functional benefit - a real diff/longest-common-substring algorithm
(ADR 0008's own next real step) is what would actually justify wiring
it in.

## Not yet done

- Whether the same "multiple `(U64)`-cast composition" pattern exists
  anywhere else in this codebase wasn't audited beyond `Canon.HC`'s
  two hot functions (`GetU32LE`/`GetU64LE`, both checked, both safe).
  A full grep-and-check pass across every file using multi-byte
  composition wasn't done in this probe.
- A real diff algorithm for `FossilDeltaMakeTrivial` - separate,
  real future work, unblocked by this fix but not started here.
