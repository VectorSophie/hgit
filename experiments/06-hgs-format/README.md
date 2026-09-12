# Probe 06 — `.HGS` versioned archive header, real TempleOS

Status: **PASS, first try.** Designs and verifies the versioned file
header the brief requires ("Portable, explicitly versioned repository/
archive format"; "Repository-format decisions are versioned, documented
byte-for-byte, and tested with golden vectors") — full byte layout in
`FORMAT.md`.

## What was done

1. Designed a minimal 16-byte header (magic `HGS0`, `U16` format
   version, `U16` reserved, `U64` object count) sitting in front of
   `Archive.HC`'s existing record format.
2. Implemented `HgsWriteHeader`/`HgsReadHeader` plus a **parameterized**
   object-append (`HgsPut`, taking the archive buffer and length as
   arguments rather than `Archive.HC`'s tested-but-global-buffer
   `ArchivePut`) — first verified instance of the parameterization
   `Archive.HC`'s own comments flagged as "future work, not yet
   verified."
3. Built a 2-object archive (`"hgitA"`, `"hgitB"`), wrote it to
   `C:/Home/test2.hgs` via `FileWrite`, read it back via `FileRead`,
   parsed the header, and ran `Archive.HC`'s existing `ArchiveVerify`
   against the object section (`rbuf+16`, `rsize-16`) to confirm every
   record's hash still checks out through a header-prefixed file.
4. Result, verbatim:
   ```
   D_OK
   wrote 170 bytes
   rsize=170 hok=1 version=1 count=2
   verify total=2 ok=2
   PASS hgs_header_roundtrip
   D_DONE
   ```
   170 bytes = 16 (header) + 2 × 77 (5-byte payload + 8-byte length +
   64-byte hash each) — matches `FORMAT.md`'s byte accounting exactly.

## Why this passed cleanly (no debugging round-trip)

Every helper here is a thin, direct reuse of already-tested code
(`Canon.HC`'s `PutU64LE`/`GetU64LE`, `Blake2b.HC`'s `B2Hash512`,
`Archive.HC`'s `ArchiveVerify`) plus straightforward new byte-layout code
following the same patterns (explicit masking, no prefix casts) that
have now been exercised three probes in a row. This is the payoff the
project's own accumulating-evidence approach is supposed to produce.

## Landed as real hgit-core source

`src/hgit-core/Hgs.HC` (diffed against this probe's `tested_source.hc`
before committing — whitespace-only differences, zero logic changes)
and `FORMAT.md` at the repo root, documenting the byte layout per the
brief's "documented byte-for-byte" requirement.

## Not yet done

- Object typing (blob/tree/commit-equivalent tags) — `FORMAT.md`
  explicitly calls this out as real next work, not yet designed.
- An index — still linear-scan only.
- Nothing yet tests `HgsReadHeader`'s FALSE path (a file that isn't a
  `.HGS` at all, or has a corrupted magic) — the brief's "test malformed
  input at every decoder boundary" applies here and hasn't been done.
