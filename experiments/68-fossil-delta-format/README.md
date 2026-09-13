# Probe 68 — Fossil delta format prototype: real HolyC quirks confirmed, one real reliability gap left honestly open

Status: **PARTIAL** — the byte-level algorithm (base-64 integers,
checksum, three-part delta structure) is confirmed correct in
isolation, with two new HolyC quirks found and fixed along the way.
But a real, unresolved reliability issue remains: the exact same
`FossilDeltaApply` call passes or fails depending on **unrelated local
variables declared in the caller**, which was bisected precisely but
not root-caused to a fix. This is reported honestly as an open risk,
not glossed over as solved.

## What this implements

`src/hgit-core/Fossil.HC` - per doc 04's own recommendation
("prototype Fossil's delta format specifically before inventing a new
one"): `FossilPutInt`/`FossilGetInt` (the base-64 variable-width
integer encoding), `FossilChecksum` (the 32-bit big-endian-word sum),
`FossilDeltaMakeTrivial` (the simplest valid delta - one literal
segment, no copy segments - proving the format's mechanics, not a real
diff algorithm), and `FossilDeltaApply` (parse + verify + reconstruct).

Every byte-level detail was taken from Fossil's own real source
(`src/delta.c`, fetched directly via `fossil-scm.org`), not a
paraphrased summary - two earlier web-search summaries of the format
actually **disagreed with each other** on the alphabet's character
order and the digit-write direction, which is exactly why the primary
source was fetched instead of trusting either.

## Real bugs found and fixed, in the order found

1. **Trivial test-driver bug** (not a Fossil.HC bug): an early test
   used `CommPrint(1, "%s", delta)` on a non-null-terminated buffer,
   which read past the intended content and appears to have crashed
   the VM outright (a hard reset, not the usual GPF-with-debugger).
   Fixed by printing byte-by-byte, bounded by the real length.

2. **Real logic bug in the segment-loop termination**: the first real
   version used `while (... && delta[pos] != ';')` to decide "is there
   another segment" - genuinely ambiguous, since the trailer's own
   checksum digits are never `;` either (only the character *after*
   all of them is). This misread the checksum as a bogus extra
   segment's length and read/wrote arbitrarily far past both `delta`
   and `target_out` - reproduced as a real VM reset. Fixed by
   terminating the loop once `tlen` reaches the header's own declared
   target length (the real, unambiguous signal - matches how a real
   Fossil reader actually works).

3. **A genuine, previously-undocumented HolyC quirk, distinct from
   Canon.HC's own documented one**: postfix-casting a raw byte read
   directly to `(I64)` produces garbage - not the zero-extended byte
   value - while casting the *exact same read* to `(U64)` works
   correctly, even when the result is immediately used in I64
   arithmetic afterward. Isolated precisely
   (`test_i64_vs_u64_cast_isolation.hc`,
   `test_array_index_cast_isolation.hc`): `buf[i](I64)` assigned to a
   fresh `I64` local printed a huge garbage number in every index form
   tried (literal, variable, expression, explicitly parenthesized);
   `buf[i](U64)` in the exact same position printed the correct value
   every time. Canon.HC's own working code already avoids this by
   convention (it only ever casts to `(U64)`, never `(I64)`, for this
   exact purpose) but doesn't call out *why* - this probe re-derives
   and documents the reason explicitly. Fixed by casting every raw
   byte read to `(U64)` throughout `Fossil.HC`, matching Canon.HC's
   established convention exactly rather than deviating from it.

4. **A real logic bug in the trailer-parsing order**: an early version
   checked for the trailer's `;` *before* reading the checksum digits,
   backwards from the real format (`<checksum-digits>;` - the digits
   come first). Always failed at that check. Fixed by reading the
   checksum integer first, then checking for `;` right after it.

## The verified-correct case

`test_driver_passing_minimal.hc` (`P68QCheck`): builds a delta from
`"hello there, big wide world!"`, applies it, and independently
recomputes the checksum on both the original and reconstructed content
- `APPLY_OK=1`, `enc_check=1127349339 dec_check=1127349339` (exact
match), reproduced twice in separate pushes. This proves the
algorithm itself - integer encoding, checksum computation, delta
structure, round-trip reconstruction - is correct when called from a
small, minimal caller.

## The real, unresolved finding: caller-stack-shape sensitivity

The **identical** `FossilDeltaApply` call, with **identical**
arguments, fails (`APPLY_OK=0`) when the calling function has
additional, unrelated local variables declared - even ones declared
*after* the call and never used to influence it.
`test_driver_failing_extra_locals.hc` (`P68SBisect`) isolates this
precisely: taking the exact passing test and adding only
`Bool match = TRUE; I64 i = 0;` after the `FossilDeltaApply` call (no
other change) flips the result from `APPLY_OK=1` to `APPLY_OK=0`,
reproduced consistently. This was bisected step by step, ruling out
several other hypotheses along the way (not a stale-redefinition
artifact - a brand-new, never-before-used function name still failed
once it had more locals; not simple non-determinism - the same minimal
test passed twice in a row, and the same larger test failed twice in a
row).

**This was not root-caused, but was narrowed much further with
additional bisection** (a second round, after the finding above was
first written up): the trigger is **not** "any extra local variable,"
"an unused one specifically," "a name collision," or "any extra
function call" - all of those were tested directly and ruled out:

- `test_fails_one_i64_local.hc` / `test_fails_one_u32_local.hc`: a
  single extra local (either type) still fails, so it isn't about
  count or type.
- `test_ruled_out_name_collision.hc`: renaming the extra locals to
  names that appear nowhere in `Fossil.HC` still fails - not a name
  collision with an internal variable (`FossilDeltaMakeTrivial` does
  use a plain `I64 i;` internally, which was the original suspect).
- `test_fails_used_plain_local.hc`: printing the extra local's value
  (so it can't be "unused") still fails - not about dead-code
  elimination of an unused declaration.
- `test_fails_unrelated_function_call.hc`: calling an unrelated kernel
  function (`StrLen`) again afterward still fails - not "any extra
  call site fixes it."
- `test_fails_unused_checksum_call.hc`: calling `FossilChecksum` again
  but discarding its result still fails.
- **`test_PASSES_used_checksum_call.hc`**: calling `FossilChecksum`
  again on the *same target content*, **and printing that result**,
  reliably and reproducibly makes the *earlier*, already-executed-and-
  printed `FossilDeltaApply` call read as success - confirmed twice in
  separate pushes, not a fluke.

That last result is genuinely strange on its own terms: the extra
`FossilChecksum` call and print are textually **after** the
`CommPrint` that already reported `ok`'s value, so it cannot be a
runtime execution-order effect on a value already computed and
printed. This points at a **compile-time code-generation effect** -
the mere presence (and use) of a second call to a specific function
elsewhere in the same source function changing how the compiler
generates code for an *earlier* call in that function - rather than
anything wrong with `FossilDeltaApply`'s own logic. This was not
pursued further (no disassembly access, and diminishing returns after
this many isolated reproductions); reported as the most specific,
evidence-backed characterization reached, not a final root cause.
Genuinely open: `Fossil.HC`'s behavior in an arbitrary real caller
remains unreliable until this is actually understood.

## What this means for adoption

`Fossil.HC` is **not** wired into `tools/build-package.sh` or any real
hgit command, and should not be until this reliability gap is closed -
the caller-shape sensitivity found here means it cannot yet be trusted
to behave the same way inside a real command's own, larger function
bodies as it does in an isolated test. This is a standalone research
prototype, per docs/adr/0008-fossil-delta-format-prototype.md's own
scope.

## Not yet done

- The caller-stack-shape bug itself (see above) - real, open,
  unresolved.
- A real diff/longest-common-substring algorithm (`FossilDeltaMakeTrivial`
  only ever produces one literal segment covering the whole target) -
  `FossilDeltaApply`'s `@` (copy-segment) parsing path is implemented
  and read, but has never been exercised by a delta that actually uses
  it.
- Wiring this into any real object-storage path (blob delta-compression
  against a prior version) - explicitly out of scope until the above
  is resolved.
