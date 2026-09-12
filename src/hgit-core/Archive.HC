// Archive.HC — minimal append-only tiny object archive for hgit.
//
// Record format (all fields via Canon.HC's explicit-endian helpers):
//   [U64 length LE][length bytes of data][64 bytes BLAKE2b-512 hash]
//
// This is deliberately minimal: no compression, no delta encoding. It
// exists to answer the M0 question "can hgit append/write/read-back/
// verify a tiny object archive on real TempleOS at all" - not to be the
// final format.
//
// Hashing uses B2Hash512Any (Blake2b.HC's streaming wrapper), not the
// single-block-only B2Hash512 - so records are NOT capped at 128 bytes.
// Verified for a 200-byte record in experiments/09-wire-streaming-hash/
// (there via parallel ArchivePutAny/ArchiveVerifyAny test functions;
// the substitution applied here - B2Hash512 -> B2Hash512Any, nothing
// else changed - is the same one-line fix, not independently re-tested
// against these exact function names).
//
// Depends on Canon.HC (PutU64LE/GetU64LE) and Blake2b.HC (B2Hash512Any).
// Load both first.
//
// IMPORTANT HolyC quirk, confirmed by testing (see
// experiments/05-tiny-archive/): a bare top-level `while` loop with
// local variable declarations inside its body can silently misbehave -
// observed as a hash-verification loop reading garbage data even though
// an otherwise-identical check done manually (outside a loop) worked
// correctly. This is NOT limited to boot-phase (the previously-known
// restriction, see doc 01) - it reproduced well after boot, at the
// ordinary interactive/JIT level. The fix, confirmed by testing: wrap
// any loop that declares its own locals in a real `U0 Foo() { ... }`
// function rather than leaving it as a bare top-level statement. Every
// function below follows this rule; don't "simplify" one into a bare
// top-level loop to save a wrapper - it silently breaks.

// NOTE: this takes the archive buffer/length as globals in the tested
// version (experiments/05-tiny-archive/tested_source.hc), not as
// parameters - kept that way here deliberately so this file matches
// what was actually run, rather than an untested "cleaner" refactor.
// Parameterizing archive_buf/arc_len (so multiple archives can coexist)
// is real future work, not yet verified - do it as its own probe.
U8 hgit_archive[1024]; // size matches what was actually tested; bump + retest before relying on more
I64 hgit_arc_len = 0;

U0 ArchivePut(U8 *data, I64 len)
{
  U8 hash[64];
  I64 i;
  B2Hash512Any(data, len, hash);
  PutU64LE(hgit_archive, hgit_arc_len, len);
  hgit_arc_len += 8;
  for (i=0; i<len; i++) hgit_archive[hgit_arc_len+i] = data[i];
  hgit_arc_len += len;
  for (i=0; i<64; i++) hgit_archive[hgit_arc_len+i] = hash[i];
  hgit_arc_len += 64;
}

// Scans a serialized archive buffer, recomputing and checking each
// record's stored hash. out_total/out_ok are counts, not indices - this
// is a verification pass, not an index build (that's the next probe).
U0 ArchiveVerify(U8 *buf, I64 total_len, I64 *out_total, I64 *out_ok)
{
  I64 pos=0, total=0, ok_count=0;
  while (pos < total_len) {
    U64 len = GetU64LE(buf, pos); pos += 8;
    U8 *data = buf + pos; pos += len;
    U8 *stored_hash = buf + pos; pos += 64;
    U8 recomputed[64];
    B2Hash512Any(data, len, recomputed);
    Bool match = TRUE;
    I64 j;
    for (j=0; j<64; j++) if (recomputed[j] != stored_hash[j]) match = FALSE;
    total++;
    if (match) ok_count++;
  }
  *out_total = total;
  *out_ok = ok_count;
}
