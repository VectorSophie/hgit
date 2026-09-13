# ADR 0008 — Prototype Fossil's delta format for future compression work

## Status

**Byte-level mechanics prototyped AND verified reliable - still not
adopted into any real command, for a different reason now.**
`src/hgit-core/Fossil.HC` (`experiments/68-fossil-delta-format/`)
implements the format's byte-level mechanics (base-64 integer
encode/decode, checksum, three-part delta structure), and the long-open
"caller-shape-sensitivity" reliability gap (probes 68/77/79) is now
**resolved** - a real root cause found and fixed in probe 80
(`experiments/80-fossil-checksum-root-cause/`): a raw byte cast to
`(U64)` does not reliably zero-extend once composed with other such
casts in one shifted-OR expression; explicitly masking each with
`& 0xFF` fixes it, verified against independently-computed ground
truth across every previously-failing reproduction. A real, if
minimal, diff algorithm now exists too (probe 82,
`experiments/82-fossil-real-diff/`, `FossilDeltaMakeReal` - single
longest-match copy segment, ~61% compression verified on a real test
case). `Fossil.HC` still isn't wired into `tools/build-package.sh` -
not for reliability or lack of a diff algorithm anymore, but because
no real hgit command currently stores or needs delta-compressed
objects; see "Decision" below.

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

## What was NOT resolved for a long time - a real, open reliability gap (now closed, see below)

The identical `FossilDeltaApply` call, with identical arguments, was
found to pass or fail depending on code **elsewhere in the calling
function, after the call**. Narrowed by extensive further bisection
(see `experiments/68-fossil-delta-format/README.md` for all nine
original reproductions, then `experiments/77-fossil-checksum-isolation/`'s
three more): not local-variable count, not type, not an unused-
variable effect, not a name collision, not "any extra function call" -
specifically, calling `FossilChecksum` again (on the same content) and
using its result reliably flipped an *already-printed* earlier
`FossilDeltaApply` result from failure to success.

**RESOLVED (probe 80, `experiments/80-fossil-checksum-root-cause/`)**:
the real root cause is a genuine HolyC compiler quirk, now understood
precisely - a raw byte cast to `(U64)` does not reliably zero-extend
once its result is shifted and composed with *other* `(U64)`-cast byte
reads in the same expression (as `FossilChecksum`'s original word-
composition did, casting three of four bytes this way). Garbage bits
above bit 7 - left over from whatever previously occupied that
register/stack slot, which is exactly why this varied with caller
shape - leak into the sum. Explicitly masking each cast byte with
`& 0xFF` before shifting fixes it: verified against an independently
computed ground-truth checksum (Python, byte-for-byte, for a real
28-byte string) - every previous version, in every caller shape,
produced a *different wrong value*; the fixed version matches exactly,
in every previously-failing reproduction re-run. `Canon.HC`'s own
`GetU32LE`/`GetU64LE` were checked directly and confirmed unaffected -
each happens to compose its bytes in a structurally different, safe
way (only one explicit `(U64)` cast in `GetU32LE`'s case; a per-byte
loop rather than one composed expression in `GetU64LE`'s), not by
outcome-blind luck once understood, but a real asymmetry now
explained rather than just observed to work.

## Decision

`Fossil.HC`'s reliability question is closed - the checksum is
correct, verified against ground truth, across every caller shape
tested - and a real, minimal diff algorithm exists
(`FossilDeltaMakeReal`, probe 82, real compression verified on a real
test case). It is still **not** added to `tools/build-package.sh` and
is not called from any real hgit command, but now for a genuine
product reason, not a technical gap: no real hgit command currently
stores or needs delta-compressed objects - the object store is
append-only, whole-content blobs, and adopting delta compression there
is a real architectural decision (would every object be delta-encoded
against a prior version? which ones? at what point in `hgit offer`'s
own pipeline?) that hasn't been made, not something to bolt on for its
own sake. The byte-level format understanding gained across probes
68/77/79/80/82 (and the HolyC quirks found, including probe 80's real
root cause) are real, durable value - the research question doc 04
raised ("does Fossil's delta format work in HolyC at all") is now
answered "yes, verified reliable, with a real working diff algorithm,
pending a real decision on whether/where hgit's own storage layer
should use it."

## What would justify revisiting this

- ~~Root-causing the caller-stack-shape sensitivity~~ **RESOLVED**
  (probe 80, `experiments/80-fossil-checksum-root-cause/`) - see
  "Decision" above. This section's own history, left in place rather
  than deleted, as the honest record of how the investigation actually
  went: **Update (probe 76, `experiments/76-compiler-source-access/`)**:
  TempleOS ships its own compiler source, readable via `FileRead`
  (`.Z` files transparently decompressed), at `D:/Compiler/` - a real
  optimizer stage (`OptPass012.HC`'s documented constant-folding/NOP-
  elimination pass) looked like a plausible match at the time.
  **Update (probe 77, `experiments/79-fossil-checksum-isolation/`)**:
  three more hypotheses ruled out; found the bug lived in the encoder,
  not the decoder. **In the end, the actual root cause turned out to
  be simpler than the optimizer-pass theory**: a raw-byte-`(U64)`-cast
  composition bug, not anything in `OptPass012` specifically - the
  compiler-source lead from probe 76 was a real, useful capability
  found along the way, just not the piece that ended up mattering for
  this specific bug.
- ~~A real diff/longest-common-substring algorithm~~ **Done, a first
  version** (probe 82, `experiments/82-fossil-real-diff/`):
  `FossilDeltaMakeReal` finds the single longest matching substring
  between source and target and encodes `[literal][copy][literal]`
  when it's worth it, falling back to `FossilDeltaMakeTrivial`'s
  all-literal shape otherwise. Verified: a real 105-byte target with
  one small edit compresses to a 41-byte delta (~61% smaller),
  byte-for-byte round-trip confirmed, plus a real no-shared-content
  negative case. This is a *first* real diff, not the format's final
  one - only one copy segment, not true multi-hunk diffing (a target
  edited in two separate places still only gets one copy segment). A
  real multi-hunk diff (e.g. a rolling-hash block matcher) remains
  real future work if that scope is ever needed.
