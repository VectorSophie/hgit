# Probe 05 — tiny object archive, append/write/read-back/verify, real TempleOS

Status: **PASS**, after finding and fixing one genuine new HolyC quirk.
Closes M0's last open checklist item: "append/read/rebuild of a tiny
object archive."

## What was done

1. Built a minimal record format on top of already-verified primitives:
   `[U64 length][data][64-byte BLAKE2b-512 hash]`, using `Canon.HC` for
   the length field and `Blake2b.HC` for the hash — first real reuse of
   *two* previously-committed hgit-core files together.
2. Appended two tiny objects ("hgit1", "hgit2") to an in-memory buffer,
   `FileWrite` to `C:/Home/test.hgs`, then `FileRead` it back. **Guessed
   `FileRead`'s signature** (`U8 *FileRead(U8 *filename, I64 *size)`,
   based on general HolyC convention — no confirmed source example was
   found in the devkit) and it was right first try: `read_size=154
   readback_null=0`, matching what was written exactly.
3. **The verification loop failed** (`objects=2 verified=0`) even though
   a manual, unrolled check of the same data (outside any loop) computed
   the exact right hash and matched the stored one perfectly. That
   contradiction — same inputs, same function, different result — was
   the interesting part.
4. Isolated it by ruling out hypotheses one at a time (cheap since the
   daemon was already alive — each retry was a few seconds, not a
   reboot): not a local-variable-argument-passing problem (calling
   `B2Hash512` with local pointer/length variables worked fine outside a
   loop); not a `FileRead` data-corruption problem (the raw bytes read
   back correctly). What isolated it: an *otherwise-identical* check,
   moved from a bare top-level `while` loop into a real
   `U0 ArchiveVerify(...) { while (...) {...} }` function, passed
   cleanly: `fn_based: total=2 ok=2`, `PASS
   tiny_archive_roundtrip_v2`.

## The quirk, precisely

**A bare top-level `while` loop that declares its own local variables
inside its body can silently misbehave — even well outside boot phase**,
which is where the previously-known top-level-loop restriction
(doc 01/08, from `templeos-devkit`'s `NOTES.md`) was documented. This is
new evidence, not a rediscovery of the same thing: those boot-phase
restrictions threw explicit "Undefined identifier" / "No global labels"
errors; this one does not error at all — it silently computes wrong
values (the loop's `recomputed[64]` local came out holding a stale/wrong
hash instead of failing loudly). **Silent corruption is worse than a
compile error** — this is exactly the kind of thing the project's own
"never assume, verify" discipline exists to catch before it's built on.

**Rule now enforced in `src/hgit-core/Archive.HC`'s comments**: any loop
that declares its own locals must live inside a real function, never as
a bare top-level statement — regardless of boot phase.

## Landed as real hgit-core source

`src/hgit-core/Archive.HC` — `ArchivePut`/`ArchiveVerify`, checked in
exactly as tested (including keeping the tested version's global-buffer
design and 1KB size rather than a cleaner-looking but unverified
pointer-parameterized refactor — see the file's own comment on that).

## Not yet done

- **Index build** — this probe only verifies records exist and match
  their hash; it doesn't build a hash→offset lookup index (a real
  archive read path needs O(1)-ish lookup, not a linear rescan).
- **Parameterized/multiple archives** — current design is a single
  global buffer; fine for a feasibility probe, not for real usage.
- **Sizes beyond ~1KB and beyond BLAKE2b's single-block limit** — not
  exercised. Both the archive buffer and the hash function have
  low ceilings right now that need lifting before this is useful for
  real objects.
- **`.HGS` extraction from a disposable guest** — the last M0 checklist
  item's other half. No `.HGS`-specific format decided yet (that's
  really an ADR-0001/ADR-0002 decision, still blocked on doc 04's
  jj/Fossil comparison, now partially done — see doc 04 update).
