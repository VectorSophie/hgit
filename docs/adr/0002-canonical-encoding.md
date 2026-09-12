# ADR 0002 — Canonical encoding: explicit fixed-width little-endian, never raw struct serialization

## Status

Accepted. Already implemented and verified (`src/hgit-core/Canon.HC`,
probe 03) — this ADR documents a decision already load-bearing in
committed code, not a future plan.

## Context

The brief requires persisted structures to use "canonical,
platform-independent serialization" and warns against letting
platform-specific structures leak into the repository format. Two real
unknowns made this concrete rather than abstract:

- HolyC's `class` struct layout/padding/alignment guarantees have not
  been read from compiler source (doc 01, still an open question) — so
  writing a `class`'s raw bytes to disk risks baking in an
  implementation detail nobody has actually verified is stable.
- Testing (probe 03) found that HolyC does **not** enforce a function's
  declared return width automatically (a `U32`-returning function can
  leak high-bit garbage unless the implementation masks explicitly) —
  direct evidence that HolyC's type system is a weaker guarantee than it
  looks, reinforcing that hand-serializing typed values without an
  explicit, tested encoding layer is risky.

## Alternatives considered

- **Raw struct memcpy to disk**: rejected. Depends on unverified
  compiler layout behavior (padding, alignment, struct field order) and
  ties the repository format to whatever one compiler happens to do
  today — directly against the brief's platform-independence
  requirement. Also blocks portability to a second toolchain
  (`holyc-lang`, ZealC) that might lay out the same `class` differently.
- **A generic serialization scheme with type tags/variable-length
  encoding (e.g. protobuf-like varints)**: not rejected outright, but
  deferred as unnecessary complexity for hgit-core's current needs
  (fixed small integer fields) — revisit if/when variable-length or
  optional fields are actually needed.

## Decision

Every persisted integer field is written and read through explicit,
tested helper functions that assemble/disassemble individual bytes in a
fixed byte order (little-endian, matching the host architecture's native
order but *specified*, not assumed) — never a bare `class` written as
raw bytes. Implemented today: `PutU32LE`/`GetU32LE`/`PutU64LE`/`GetU64LE`
in `Canon.HC`, reused unmodified by `Blake2b.HC` and `Archive.HC`. Every
accessor that returns a width narrower than 64 bits masks its result
explicitly before returning, per the confirmed quirk above — this is now
a standing project rule (documented inline in `Canon.HC` and
`failed-approaches.md`), not merely this ADR's advice.

## Costs

- More verbose than a struct cast — every field access is a function
  call, not a pointer dereference. Accepted deliberately; the brief
  prioritizes correctness and portability over this kind of terseness.
- No variable-length or optional-field support yet. Every format that
  needs one (probably the object-type tags from ADR 0001) will need new
  helpers, not automatic support from what exists today.

## What would justify revisiting this

- A confirmed, source-verified guarantee about HolyC `class` layout
  stability across compilers/versions that would make direct struct
  serialization provably safe — even then, cross-toolchain portability
  (ZealC, `holyc-lang`) would still argue against relying on it.
- A real performance problem specifically attributable to per-field
  function-call overhead, measured against an actual corpus (not
  assumed).
