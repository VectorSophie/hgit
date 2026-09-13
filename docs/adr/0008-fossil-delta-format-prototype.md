# ADR 0008 — Prototype Fossil's delta format for future compression work

## Status

**Prototyped, partially verified - NOT adopted into any real command
yet.** `src/hgit-core/Fossil.HC` (`experiments/68-fossil-delta-format/`)
implements the format's byte-level mechanics (base-64 integer
encode/decode, checksum, three-part delta structure) and confirms them
correct in a controlled, minimal test. A real, unresolved reliability
issue was found and left open (see "What would justify revisiting
this" below) - this ADR records a real research/prototyping step, not
a decision to actually use this format in hgit's object storage yet.

## Context

`docs/research/04-vcs-comparison.md` recommended prototyping Fossil's
delta format specifically, once hgit-core needs delta compression
(flagged as not-yet-started in doc 06), rather than inventing a new
format from scratch - Fossil's format is simple, self-describing
(length-prefixed, checksummed, human-auditable), and ASCII-safe,
matching this project's own stated preference for readable native
formats over maximal compression ratio.

## What was actually done

Implemented the format's real mechanics byte-exactly, sourced directly
from Fossil's own `src/delta.c` (not a paraphrased summary - two
different web summaries of the format disagreed with each other on
real details, which is exactly why the primary source was fetched
instead of trusted secondhand):

- `FossilPutInt`/`FossilGetInt`: the base-64 variable-width integer
  encoding (alphabet `0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~`,
  most-significant 6-bit group written first).
- `FossilChecksum`: the 32-bit big-endian-word sum with natural
  (mod 2^32) wraparound.
- `FossilDeltaMakeTrivial`: builds the simplest possible valid delta -
  the whole target as one literal segment, no copy segments - proving
  the format's structure round-trips, not a real diff algorithm (that
  remains real, separate future work).
- `FossilDeltaApply`: parses and verifies a delta against its own
  trailer checksum, reconstructing the target.

## Real bugs found and fixed along the way

Two genuinely new things, beyond what any prior probe had found:

- **A HolyC quirk distinct from Canon.HC's own documented one**:
  postfix-casting a raw byte read directly to `(I64)` produces
  garbage; casting the same read to `(U64)` works correctly even when
  the result is then used in I64 arithmetic. Canon.HC's own working
  code already avoided this by convention (always `(U64)`, never
  `(I64)`, for this purpose) without documenting *why* - this probe
  isolated and confirmed the reason directly.
- A real logic bug in trailer-parsing order (checksum digits come
  before the `;`, not after) and a real logic bug in segment-loop
  termination (scanning for `;` is ambiguous with the trailer's own
  digits) - both found via real reproduction (a genuine VM reset in
  the second case), not by inspection alone.

See `experiments/68-fossil-delta-format/README.md` for the full,
honest account of each, in the order found.

## What was NOT resolved - a real, open reliability gap

The identical `FossilDeltaApply` call, with identical arguments, was
found to pass or fail depending on code **elsewhere in the calling
function, after the call**. Narrowed by extensive further bisection
(see `experiments/68-fossil-delta-format/README.md` for all nine
reproductions): not local-variable count, not type, not an unused-
variable effect, not a name collision, not "any extra function call" -
specifically, calling `FossilChecksum` again (on the same content) and
using its result reliably flips an *already-printed* earlier
`FossilDeltaApply` result from failure to success. Since that extra
call is textually after the point where the affected value was
already computed and printed, this cannot be a runtime execution-order
effect - it points at a compile-time code-generation interaction
specific to this JIT compiler, not a logic bug in `Fossil.HC` itself.
Not pursued to a final root cause (no disassembly access). **Not
fixed, not glossed over.**

## Decision

Given the above, this ADR records the prototype as **built and
partially verified, not adopted**: `Fossil.HC` is not added to
`tools/build-package.sh` and is not called from any real hgit command.
The byte-level format understanding gained here (and the two new HolyC
quirks found) are real, durable value from this probe even though the
format itself isn't ready to use - the research question doc 04 raised
("does Fossil's delta format work in HolyC at all") is answered
"yes, for the algorithm itself, with an unresolved reliability
question about how it behaves inside a real caller."

## What would justify revisiting this

- Root-causing the caller-stack-shape sensitivity found above - without
  that, this format cannot be trusted inside a real command's own
  (necessarily larger, more local-variable-heavy) functions.
  **Update (probe 76, `experiments/76-compiler-source-access/`)**:
  this is no longer a fully black-box question - TempleOS ships its
  own compiler source, readable via `FileRead` (`.Z` files transparently
  decompressed), at `D:/Compiler/`. `OptPass012.HC`'s own documented
  Pass#1&2 ("constant expressions are simplified, eliminated opcodes
  are set to NOP") is a real, named optimizer stage whose known
  failure mode matches this bug's exact trigger (a later use of a
  value changing whether an earlier computation of it gets folded
  away). Not traced to a full root cause yet - a concrete next step
  with real source to read, not an unexplained black box anymore.
  **Update (probe 77, `experiments/79-fossil-checksum-isolation/`)**:
  three more real hypotheses tested and ruled out (mixed-signedness
  comparison; stack-buffer overlap via heap allocation; an
  intermediate return-value local). A real new fact found: the bug is
  in the *encoder*, not the decoder - `FossilDeltaMakeTrivial`'s own
  call to `FossilChecksum` already returns the wrong value, confirmed
  by instrumenting both functions and comparing their printed
  checksums directly. Also: it does **not** reproduce calling
  `FossilChecksum` directly from the shape-sensitive caller - only
  through the `FossilDeltaMakeTrivial` nesting layer specifically.
  Real, additional narrowing, still not a fix.
- A real diff/longest-common-substring algorithm, once the above is
  resolved - `FossilDeltaMakeTrivial`'s one-literal-segment approach
  has no compression value by itself; the actual benefit only comes
  from real copy segments referencing the source.
