# Probe 09 — wiring the streaming hash into the object-archive pipeline

Status: **PASS, first try.** Closes the gap probe 08 honestly flagged:
the streaming hash existed but `ArchivePut`/`ArchiveVerify`/`HgsPut`
still called the 128-byte-capped `B2Hash512`. Real (>128-byte) objects
could not actually be stored through the archive API before this probe,
despite the hash primitive itself working.

## What was tested

Using parallel `ArchivePutAny`/`ArchiveVerifyAny` functions (same logic
as `Archive.HC`'s originals, calling the new `B2Hash512Any` instead of
`B2Hash512`) to avoid touching committed source before it's verified:

1. Built an archive with one 5-byte object and one 200-byte object (the
   same message probe 08 already verified against a host oracle).
2. Confirmed the 200-byte object's stored hash's first 4 bytes match
   probe 08's known-good digest (`DD82E80E...`) — cross-checking against
   a *different* probe's independently-verified result, not just
   internal self-consistency.
3. Wrote the archive to `C:/Home/test4.hgs`, read it back, and verified
   **both** objects (the small one and the 200-byte one) via
   `ArchiveVerifyAny` — `verify_total=2 verify_ok=2`.
4. Final: `PASS wire_streaming_into_archive`, first push, no retry
   needed.

## Applied to real hgit-core source

The fix is a one-line-per-call-site substitution — `B2Hash512` →
`B2Hash512Any` — applied directly to `Archive.HC` (both `ArchivePut` and
`ArchiveVerify`) and `Hgs.HC` (`HgsPut`), plus the new `B2Hash512Any`
wrapper itself added to `Blake2b.HC`. This is **not** a byte-for-byte
diff against a separately-tested file (unlike most prior probes) — the
parallel `*Any` functions tested here prove the substitution's behavior,
and the same substitution was then applied directly to the real
functions under their real names. Worth being explicit about that
distinction rather than implying a diff was done that wasn't.

## Not yet done

- `ObjectPut` (which calls `HgsPut`, so benefits from this fix
  transitively) still caps content at 127 bytes via its own
  `tagged[128]` local scratch buffer — a separate, smaller limitation
  than the one this probe removed. Noted in `Object.HC` and
  `FORMAT.md`.
- Real tree/commit object *content* design is still the next actual
  step now that both the hashing and the storage plumbing support
  arbitrary length.
