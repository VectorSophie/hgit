// Canon.HC — canonical little-endian integer encode/decode for hgit's
// on-disk formats. This is the first piece of hgit-core: everything
// persisted (object headers, index entries, archive metadata) goes
// through these, never a raw struct memcpy.
//
// Why not just write the struct bytes directly: HolyC has no declared
// struct packing/alignment guarantee documented yet (open question,
// doc 01), and native byte order should never leak into a portable
// repository format regardless. Fixed-width, explicit-byte-order
// encode/decode sidesteps both concerns at the cost of a few more lines.
//
// IMPORTANT HolyC quirk, confirmed by testing (see
// experiments/03-canonical-encoding/): a function declared to return
// U32 (or any width narrower than 64 bits) does NOT get its result
// truncated to that width automatically. Accumulating shifted bytes
// into a wider (U64) local and explicitly masking with `& 0xFFFFFFFF`
// before returning is required, or garbage high bits leak into the
// caller (verified: printing the "raw" unmasked result showed correct
// low 32 bits with ~20 bits of leftover garbage above them). Every
// GetU32LE-shaped function in this file masks explicitly for this
// reason — don't remove the mask as "redundant."
//
// Second HolyC quirk, confirmed the same way: there is no C-style
// prefix typecast `(U32)x`. HolyC uses a POSTFIX typecast: `x(U32)`.
// See holyc-parser's corpus entry
// tests/corpus/passing/079-expr-expr-postfix-typecast.hc in
// experiments/templeos-devkit for the authoritative example this was
// checked against.

U0 PutU32LE(U8 *buf, I64 off, U32 v)
{
  buf[off+0] = v & 0xFF;
  buf[off+1] = (v >> 8)  & 0xFF;
  buf[off+2] = (v >> 16) & 0xFF;
  buf[off+3] = (v >> 24) & 0xFF;
}

U32 GetU32LE(U8 *buf, I64 off)
{
  U64 v = buf[off] | (buf[off+1] << 8) | (buf[off+2] << 16)
        | (buf[off+3](U64) << 24);
  return v & 0xFFFFFFFF;
}

U0 PutU64LE(U8 *buf, I64 off, U64 v)
{
  I64 i;
  for (i = 0; i < 8; i++) buf[off+i] = (v >> (i*8)) & 0xFF;
}

U64 GetU64LE(U8 *buf, I64 off)
{
  U64 v = 0;
  I64 i;
  for (i = 0; i < 8; i++) v |= buf[off+i](U64) << (i*8);
  return v;
}
// Blake2b.HC — BLAKE2b-512, unkeyed, single-block (input <= 111 bytes)
// implementation of hgit's authoritative content hash.
//
// Verified against the official RFC 7693 Appendix A worked example
// (unkeyed BLAKE2b-512 of "abc") running natively on real TempleOS via
// the injection channel in experiments/01-temple-repl/ — see
// experiments/04-blake2b-native/. Exact digest match, byte for byte,
// against both the RFC vector and this project's own host-side oracle
// (experiments/02-blake2b-oracle/), so this satisfies the M0 checklist's
// "same fixture hashes identically in TempleOS and a host build" as well
// as "official BLAKE2b vectors passing in native HolyC".
//
// B2Hash512 below only handles messages that fit in one 128-byte block.
// For anything larger, use the B2StreamInit/B2StreamUpdate/B2StreamFinal
// API further down this file (verified against 200- and 300-byte
// messages, including cross-call-boundary buffering, in
// experiments/08-blake2b-streaming/). Both share the same B2Compress/
// B2G/B2Init - B2Hash512 is kept as-is (not rewritten in terms of the
// streaming API) since it's already verified against RFC 7693 and there
// was no reason to disturb that.
//
// Depends on Canon.HC's GetU64LE/PutU64LE for endian-correct byte<->word
// conversion - load that first.

U64 B2_IV[8];
I64 B2_SIGMA[192];

// Filled by explicit assignment, not an aggregate initializer literal -
// generated from a Python script (see experiments/04-blake2b-native/
// gen_tables.py) to avoid hand-transcription errors across 8 IV words
// and 192 SIGMA permutation entries. This is the exact body that was
// pushed through the injection channel and verified - not a stub.
U0 B2Init()
{
  B2_IV[0] = 0x6A09E667F3BCC908;
  B2_IV[1] = 0xBB67AE8584CAA73B;
  B2_IV[2] = 0x3C6EF372FE94F82B;
  B2_IV[3] = 0xA54FF53A5F1D36F1;
  B2_IV[4] = 0x510E527FADE682D1;
  B2_IV[5] = 0x9B05688C2B3E6C1F;
  B2_IV[6] = 0x1F83D9ABFB41BD6B;
  B2_IV[7] = 0x5BE0CD19137E2179;
  B2_SIGMA[0] = 0;
  B2_SIGMA[1] = 1;
  B2_SIGMA[2] = 2;
  B2_SIGMA[3] = 3;
  B2_SIGMA[4] = 4;
  B2_SIGMA[5] = 5;
  B2_SIGMA[6] = 6;
  B2_SIGMA[7] = 7;
  B2_SIGMA[8] = 8;
  B2_SIGMA[9] = 9;
  B2_SIGMA[10] = 10;
  B2_SIGMA[11] = 11;
  B2_SIGMA[12] = 12;
  B2_SIGMA[13] = 13;
  B2_SIGMA[14] = 14;
  B2_SIGMA[15] = 15;
  B2_SIGMA[16] = 14;
  B2_SIGMA[17] = 10;
  B2_SIGMA[18] = 4;
  B2_SIGMA[19] = 8;
  B2_SIGMA[20] = 9;
  B2_SIGMA[21] = 15;
  B2_SIGMA[22] = 13;
  B2_SIGMA[23] = 6;
  B2_SIGMA[24] = 1;
  B2_SIGMA[25] = 12;
  B2_SIGMA[26] = 0;
  B2_SIGMA[27] = 2;
  B2_SIGMA[28] = 11;
  B2_SIGMA[29] = 7;
  B2_SIGMA[30] = 5;
  B2_SIGMA[31] = 3;
  B2_SIGMA[32] = 11;
  B2_SIGMA[33] = 8;
  B2_SIGMA[34] = 12;
  B2_SIGMA[35] = 0;
  B2_SIGMA[36] = 5;
  B2_SIGMA[37] = 2;
  B2_SIGMA[38] = 15;
  B2_SIGMA[39] = 13;
  B2_SIGMA[40] = 10;
  B2_SIGMA[41] = 14;
  B2_SIGMA[42] = 3;
  B2_SIGMA[43] = 6;
  B2_SIGMA[44] = 7;
  B2_SIGMA[45] = 1;
  B2_SIGMA[46] = 9;
  B2_SIGMA[47] = 4;
  B2_SIGMA[48] = 7;
  B2_SIGMA[49] = 9;
  B2_SIGMA[50] = 3;
  B2_SIGMA[51] = 1;
  B2_SIGMA[52] = 13;
  B2_SIGMA[53] = 12;
  B2_SIGMA[54] = 11;
  B2_SIGMA[55] = 14;
  B2_SIGMA[56] = 2;
  B2_SIGMA[57] = 6;
  B2_SIGMA[58] = 5;
  B2_SIGMA[59] = 10;
  B2_SIGMA[60] = 4;
  B2_SIGMA[61] = 0;
  B2_SIGMA[62] = 15;
  B2_SIGMA[63] = 8;
  B2_SIGMA[64] = 9;
  B2_SIGMA[65] = 0;
  B2_SIGMA[66] = 5;
  B2_SIGMA[67] = 7;
  B2_SIGMA[68] = 2;
  B2_SIGMA[69] = 4;
  B2_SIGMA[70] = 10;
  B2_SIGMA[71] = 15;
  B2_SIGMA[72] = 14;
  B2_SIGMA[73] = 1;
  B2_SIGMA[74] = 11;
  B2_SIGMA[75] = 12;
  B2_SIGMA[76] = 6;
  B2_SIGMA[77] = 8;
  B2_SIGMA[78] = 3;
  B2_SIGMA[79] = 13;
  B2_SIGMA[80] = 2;
  B2_SIGMA[81] = 12;
  B2_SIGMA[82] = 6;
  B2_SIGMA[83] = 10;
  B2_SIGMA[84] = 0;
  B2_SIGMA[85] = 11;
  B2_SIGMA[86] = 8;
  B2_SIGMA[87] = 3;
  B2_SIGMA[88] = 4;
  B2_SIGMA[89] = 13;
  B2_SIGMA[90] = 7;
  B2_SIGMA[91] = 5;
  B2_SIGMA[92] = 15;
  B2_SIGMA[93] = 14;
  B2_SIGMA[94] = 1;
  B2_SIGMA[95] = 9;
  B2_SIGMA[96] = 12;
  B2_SIGMA[97] = 5;
  B2_SIGMA[98] = 1;
  B2_SIGMA[99] = 15;
  B2_SIGMA[100] = 14;
  B2_SIGMA[101] = 13;
  B2_SIGMA[102] = 4;
  B2_SIGMA[103] = 10;
  B2_SIGMA[104] = 0;
  B2_SIGMA[105] = 7;
  B2_SIGMA[106] = 6;
  B2_SIGMA[107] = 3;
  B2_SIGMA[108] = 9;
  B2_SIGMA[109] = 2;
  B2_SIGMA[110] = 8;
  B2_SIGMA[111] = 11;
  B2_SIGMA[112] = 13;
  B2_SIGMA[113] = 11;
  B2_SIGMA[114] = 7;
  B2_SIGMA[115] = 14;
  B2_SIGMA[116] = 12;
  B2_SIGMA[117] = 1;
  B2_SIGMA[118] = 3;
  B2_SIGMA[119] = 9;
  B2_SIGMA[120] = 5;
  B2_SIGMA[121] = 0;
  B2_SIGMA[122] = 15;
  B2_SIGMA[123] = 4;
  B2_SIGMA[124] = 8;
  B2_SIGMA[125] = 6;
  B2_SIGMA[126] = 2;
  B2_SIGMA[127] = 10;
  B2_SIGMA[128] = 6;
  B2_SIGMA[129] = 15;
  B2_SIGMA[130] = 14;
  B2_SIGMA[131] = 9;
  B2_SIGMA[132] = 11;
  B2_SIGMA[133] = 3;
  B2_SIGMA[134] = 0;
  B2_SIGMA[135] = 8;
  B2_SIGMA[136] = 12;
  B2_SIGMA[137] = 2;
  B2_SIGMA[138] = 13;
  B2_SIGMA[139] = 7;
  B2_SIGMA[140] = 1;
  B2_SIGMA[141] = 4;
  B2_SIGMA[142] = 10;
  B2_SIGMA[143] = 5;
  B2_SIGMA[144] = 10;
  B2_SIGMA[145] = 2;
  B2_SIGMA[146] = 8;
  B2_SIGMA[147] = 4;
  B2_SIGMA[148] = 7;
  B2_SIGMA[149] = 6;
  B2_SIGMA[150] = 1;
  B2_SIGMA[151] = 5;
  B2_SIGMA[152] = 15;
  B2_SIGMA[153] = 11;
  B2_SIGMA[154] = 9;
  B2_SIGMA[155] = 14;
  B2_SIGMA[156] = 3;
  B2_SIGMA[157] = 12;
  B2_SIGMA[158] = 13;
  B2_SIGMA[159] = 0;
  B2_SIGMA[160] = 0;
  B2_SIGMA[161] = 1;
  B2_SIGMA[162] = 2;
  B2_SIGMA[163] = 3;
  B2_SIGMA[164] = 4;
  B2_SIGMA[165] = 5;
  B2_SIGMA[166] = 6;
  B2_SIGMA[167] = 7;
  B2_SIGMA[168] = 8;
  B2_SIGMA[169] = 9;
  B2_SIGMA[170] = 10;
  B2_SIGMA[171] = 11;
  B2_SIGMA[172] = 12;
  B2_SIGMA[173] = 13;
  B2_SIGMA[174] = 14;
  B2_SIGMA[175] = 15;
  B2_SIGMA[176] = 14;
  B2_SIGMA[177] = 10;
  B2_SIGMA[178] = 4;
  B2_SIGMA[179] = 8;
  B2_SIGMA[180] = 9;
  B2_SIGMA[181] = 15;
  B2_SIGMA[182] = 13;
  B2_SIGMA[183] = 6;
  B2_SIGMA[184] = 1;
  B2_SIGMA[185] = 12;
  B2_SIGMA[186] = 0;
  B2_SIGMA[187] = 2;
  B2_SIGMA[188] = 11;
  B2_SIGMA[189] = 7;
  B2_SIGMA[190] = 5;
  B2_SIGMA[191] = 3;
}

U64 B2Rotr(U64 x, I64 n)
{
  return (x >> n) | (x << (64-n));
}

U0 B2G(U64 *v, I64 a, I64 b, I64 c, I64 d, U64 x, U64 y)
{
  v[a] = v[a] + v[b] + x;
  v[d] = B2Rotr(v[d] ^ v[a], 32);
  v[c] = v[c] + v[d];
  v[b] = B2Rotr(v[b] ^ v[c], 24);
  v[a] = v[a] + v[b] + y;
  v[d] = B2Rotr(v[d] ^ v[a], 16);
  v[c] = v[c] + v[d];
  v[b] = B2Rotr(v[b] ^ v[c], 63);
}

U0 B2Compress(U64 *h, U64 *m, U64 t0, U64 t1, Bool final)
{
  U64 v[16];
  I64 i, r;
  I64 *s;
  for (i=0; i<8; i++) v[i] = h[i];
  for (i=0; i<8; i++) v[8+i] = B2_IV[i];
  v[12] ^= t0;
  v[13] ^= t1;
  if (final) v[14] = ~v[14];
  for (r=0; r<12; r++) {
    s = &B2_SIGMA[r*16];
    B2G(v,0,4,8,12,  m[s[0]], m[s[1]]);
    B2G(v,1,5,9,13,  m[s[2]], m[s[3]]);
    B2G(v,2,6,10,14, m[s[4]], m[s[5]]);
    B2G(v,3,7,11,15, m[s[6]], m[s[7]]);
    B2G(v,0,5,10,15, m[s[8]], m[s[9]]);
    B2G(v,1,6,11,12, m[s[10]], m[s[11]]);
    B2G(v,2,7,8,13,  m[s[12]], m[s[13]]);
    B2G(v,3,4,9,14,  m[s[14]], m[s[15]]);
  }
  for (i=0; i<8; i++) h[i] ^= v[i] ^ v[8+i];
}

// Hashes msg (len bytes, len<=128 - single block, no multi-block
// streaming yet) into out64 (caller-allocated 64-byte buffer).
U0 B2Hash512(U8 *msg, I64 len, U8 *out64)
{
  U64 h[8];
  U8 mbuf[128];
  U64 m[16];
  I64 i;
  B2Init();
  for (i=0; i<8; i++) h[i] = B2_IV[i];
  h[0] ^= 0x0000000001010040;   // digest_length=64, key_length=0, fanout=1, depth=1
  for (i=0; i<128; i++) mbuf[i] = 0;
  for (i=0; i<len; i++) mbuf[i] = msg[i];
  for (i=0; i<16; i++) m[i] = GetU64LE(mbuf, i*8);
  B2Compress(h, m, len, 0, TRUE);
  for (i=0; i<8; i++) PutU64LE(out64, i*8, h[i]);
}

// --- Multi-block streaming (verified experiments/08-blake2b-streaming/) ---
//
// The single-block B2Hash512 above only handles messages that fit in
// one 128-byte block. This adds the standard incremental Init/Update/
// Final pattern: buffer bytes up to 128, compress-as-non-final and
// reset the buffer whenever it fills *while more input remains*,
// zero-pad and compress-as-final whatever's left in Final(). Verified
// against Python's hashlib.blake2b for 200-byte (2-block) and 300-byte
// (3-block) messages, including a message deliberately split across
// three separate Update() calls at non-block-aligned offsets to
// exercise the cross-call buffering - all matched exactly. Also
// verified this streaming path produces the identical digest as
// B2Hash512 for a message ("abc") both can handle, as a regression
// check.
//
// Global state (single in-flight hash at a time) rather than a
// parameterized "context struct" - deliberately, per ADR 0002's
// reasoning: HolyC struct/class layout guarantees haven't been
// verified from source, so this avoids relying on one until that's
// resolved. Parameterizing (so multiple hashes can be in flight at
// once) is real future work, not yet needed or verified.
U64 b2s_h[8];
U8 b2s_buf[128];
I64 b2s_buflen;
U64 b2s_t0;

U0 B2StreamInit()
{
  I64 i;
  B2Init();
  for (i=0; i<8; i++) b2s_h[i] = B2_IV[i];
  b2s_h[0] ^= 0x0000000001010040;
  b2s_buflen = 0;
  b2s_t0 = 0;
}

U0 B2StreamCompressBuf(Bool final)
{
  U64 m[16];
  I64 i;
  for (i=0; i<16; i++) m[i] = GetU64LE(b2s_buf, i*8);
  B2Compress(b2s_h, m, b2s_t0, 0, final);
}

U0 B2StreamUpdate(U8 *data, I64 len)
{
  I64 i = 0;
  while (i < len) {
    if (b2s_buflen == 128) {
      b2s_t0 += 128;
      B2StreamCompressBuf(FALSE);
      b2s_buflen = 0;
    }
    b2s_buf[b2s_buflen] = data[i];
    b2s_buflen++;
    i++;
  }
}

U0 B2StreamFinal(U8 *out64)
{
  I64 i;
  b2s_t0 += b2s_buflen;
  for (i=b2s_buflen; i<128; i++) b2s_buf[i] = 0;
  B2StreamCompressBuf(TRUE);
  for (i=0; i<8; i++) PutU64LE(out64, i*8, b2s_h[i]);
}

// Any-length convenience wrapper over the streaming API above - use
// this (not B2Hash512) for anything that isn't guaranteed to fit in one
// 128-byte block. Verified in experiments/09-wire-streaming-hash/ as
// the actual hash call inside ArchivePut/ArchiveVerify/HgsPut.
U0 B2Hash512Any(U8 *data, I64 len, U8 *out64)
{
  B2StreamInit();
  B2StreamUpdate(data, len);
  B2StreamFinal(out64);
}
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
// Hgs.HC — .HGS archive file header, per FORMAT.md.
//
// A .HGS file is: [16-byte header][object records, see Archive.HC].
// Verified end-to-end on real TempleOS (write, FileWrite to disk,
// FileRead back, header parsed, every object hash re-verified) — see
// experiments/06-hgs-format/.
//
// Depends on Canon.HC and Archive.HC (for HgsPut's record shape and
// ArchiveVerify for checking the object section). Load both first.

// Header layout (16 bytes total, all multi-byte fields little-endian):
//   [0..3]  magic: the ASCII bytes 'H' 'G' 'S' '0'
//   [4..5]  U16 format_version
//   [6..7]  U16 reserved (must be 0; readers should ignore, not reject,
//           a nonzero value here for now - no meaning assigned yet)
//   [8..15] U64 object_count
U0 HgsWriteHeader(U8 *buf, U16 version, U64 obj_count)
{
  buf[0]='H'; buf[1]='G'; buf[2]='S'; buf[3]='0';
  buf[4] = version & 0xFF;
  buf[5] = (version >> 8) & 0xFF;
  buf[6] = 0;
  buf[7] = 0;
  PutU64LE(buf, 8, obj_count);
}

// Returns FALSE (and leaves *version_out/*obj_count_out unset) if the
// magic bytes don't match - callers must check this before trusting the
// rest of the buffer as a .HGS file.
Bool HgsReadHeader(U8 *buf, U16 *version_out, U64 *obj_count_out)
{
  if (buf[0]!='H' || buf[1]!='G' || buf[2]!='S' || buf[3]!='0') return FALSE;
  *version_out = buf[4] | (buf[5] << 8);
  *obj_count_out = GetU64LE(buf, 8);
  return TRUE;
}

// Parameterized object-append (writes into archive_buf/len rather than
// Archive.HC's ArchivePut's fixed globals - this is the first tested
// instance of the parameterized version Archive.HC's own comments flag
// as "future work, not yet verified." It is verified now.) Same record
// shape as ArchivePut: [U64 length][data][64-byte BLAKE2b hash].
U0 HgsPut(U8 *archive_buf, I64 *len, U8 *data, I64 dlen)
{
  U8 h[64];
  I64 i;
  B2Hash512Any(data, dlen, h);
  PutU64LE(archive_buf, *len, dlen);
  *len += 8;
  for (i=0; i<dlen; i++) archive_buf[*len+i] = data[i];
  *len += dlen;
  for (i=0; i<64; i++) archive_buf[*len+i] = h[i];
  *len += 64;
}
// Object.HC — typed objects on top of the .HGS record format.
//
// Per ADR 0001/0003: the base .HGS record ([length][data][hash], see
// Archive.HC/Hgs.HC) is an undifferentiated byte blob. This file adds
// hgit's actual object types (blob/tree/commit-equivalent) by
// prepending a single type-tag byte to the content BEFORE hashing and
// storing it — so the type participates in the content address, the
// same way Git's "blob <size>\0" header does. Verified
// (experiments/07-object-typing/): identical bytes stored as two
// different types hash differently, exactly as intended.
//
// Depends on Hgs.HC (HgsPut) and, transitively, Canon.HC/Blake2b.HC.

#define OBJ_BLOB   1
#define OBJ_TREE   2
#define OBJ_COMMIT 3

// Tags `data` with `type` and appends it as one .HGS record. HgsPut
// underneath hashes via B2Hash512Any, so there's no BLAKE2b block-size
// cap; this function's own `tagged[4096]` scratch buffer is the only
// remaining limit (dlen+1 <= 4096), verified up to a 146-byte tree
// object in experiments/10-tree-object/. Bump further (or switch to
// MAlloc) if a real object ever needs more - not yet exercised past
// this size.
U0 ObjectPut(U8 *archive_buf, I64 *len, U8 type, U8 *data, I64 dlen)
{
  U8 tagged[4096];
  I64 i;
  tagged[0] = type;
  for (i=0; i<dlen; i++) tagged[1+i] = data[i];
  HgsPut(archive_buf, len, tagged, dlen+1);
}

// Reads the type tag of the object record whose length field starts at
// `offset` within archive_buf - i.e. offset is the same value ObjectPut
// returned via *len *before* that call (the record's start position).
U8 ObjectPeekType(U8 *archive_buf, I64 offset)
{
  I64 pos = offset + 8; // skip the 8-byte length field
  return archive_buf[pos];
}
// Tree content format (this IS the `data`/`dlen` passed to ObjectPut
// with type=OBJ_TREE):
//   U32 entry_count
//   repeated entry_count times:
//     U8 name_len
//     name_len bytes of name (no NUL terminator, no path separators
//     handled here - flat single-level names only for this probe)
//     U8 child_type  (OBJ_BLOB or OBJ_TREE)
//     64 bytes child_hash

U0 TreeEncodeEntry(U8 *buf, I64 *len, U8 *name, I64 name_len,
                    U8 child_type, U8 *child_hash)
{
  I64 i;
  buf[*len] = name_len; *len += 1;
  for (i=0; i<name_len; i++) buf[*len+i] = name[i];
  *len += name_len;
  buf[*len] = child_type; *len += 1;
  for (i=0; i<64; i++) buf[*len+i] = child_hash[i];
  *len += 64;
}

// Finds the entry named `name` (name_len bytes) inside a decoded tree
// buffer and copies its type into *type_out, hash into hash_out (64
// bytes). Returns FALSE if not found.
Bool TreeFindEntry(U8 *tree_buf, I64 tree_len, U8 *name, I64 name_len,
                   U8 *type_out, U8 *hash_out)
{
  U32 count = GetU32LE(tree_buf, 0);
  I64 pos = 4;
  U32 e;
  for (e=0; e<count; e++) {
    U8 this_name_len = tree_buf[pos]; pos += 1;
    Bool same = (this_name_len == name_len);
    I64 i;
    if (same) for (i=0; i<name_len; i++) if (tree_buf[pos+i]!=name[i]) same=FALSE;
    U8 this_type = tree_buf[pos+this_name_len];
    U8 *this_hash = tree_buf + pos + this_name_len + 1;
    if (same) {
      *type_out = this_type;
      for (i=0; i<64; i++) hash_out[i] = this_hash[i];
      return TRUE;
    }
    pos += this_name_len + 1 + 64;
  }
  return FALSE;
}

// --- build two blobs, then a tree referencing them ---
U8 archive[4096];
I64 alen = 16;
HgsWriteHeader(archive, 1, 3); // 2 blobs + 1 tree

U8 blob1_data[5]; blob1_data[0]='h';blob1_data[1]='e';blob1_data[2]='l';blob1_data[3]='l';blob1_data[4]='o';
U8 blob2_data[5]; blob2_data[0]='w';blob2_data[1]='o';blob2_data[2]='r';blob2_data[3]='l';blob2_data[4]='d';

U8 blob1_hash[64], blob2_hash[64];
U8 tagged1[6]; tagged1[0]=OBJ_BLOB; tagged1[1]='h';tagged1[2]='e';tagged1[3]='l';tagged1[4]='l';tagged1[5]='o';
B2Hash512Any(tagged1, 6, blob1_hash);
U8 tagged2[6]; tagged2[0]=OBJ_BLOB; tagged2[1]='w';tagged2[2]='o';tagged2[3]='r';tagged2[4]='l';tagged2[5]='d';
B2Hash512Any(tagged2, 6, blob2_hash);

ObjectPut(archive, &alen, OBJ_BLOB, blob1_data, 5);
ObjectPut(archive, &alen, OBJ_BLOB, blob2_data, 5);

U8 tree_content[512];
I64 tlen = 0;
PutU32LE(tree_content, 0, 2); tlen = 4;
U8 name_a[5]; name_a[0]='a';name_a[1]='.';name_a[2]='t';name_a[3]='x';name_a[4]='t';
U8 name_b[5]; name_b[0]='b';name_b[1]='.';name_b[2]='t';name_b[3]='x';name_b[4]='t';
TreeEncodeEntry(tree_content, &tlen, name_a, 5, OBJ_BLOB, blob1_hash);
TreeEncodeEntry(tree_content, &tlen, name_b, 5, OBJ_BLOB, blob2_hash);
CommPrint(1,"tree_content_len=%d (exceeds old 127-byte ObjectPut cap: %d)\n", tlen, tlen>127);

I64 tree_off = alen;
ObjectPut(archive, &alen, OBJ_TREE, tree_content, tlen);
CommPrint(1,"alen=%d\n", alen);

FileWrite("C:/Home/test5.hgs", archive, alen);
I64 rsize; U8 *rbuf = FileRead("C:/Home/test5.hgs", &rsize);
U16 rver; U64 rcount;
Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
I64 vt, vok;
ArchiveVerify(rbuf+16, rsize-16, &vt, &vok);
CommPrint(1,"reload: hok=%d count=%d verify_total=%d verify_ok=%d\n", hok, rcount, vt, vok);

// Re-read the tree object's content back out of the reloaded buffer and
// decode it, confirming both entries resolve to the right hash+type.
I64 tree_pos_in_file = tree_off + 8; // skip length field -> points at [type][content...]
U8 reloaded_type = rbuf[tree_pos_in_file];
U8 *reloaded_tree_content = rbuf + tree_pos_in_file + 1;

U8 found_type_a, found_hash_a[64];
Bool found_a = TreeFindEntry(reloaded_tree_content, tlen, name_a, 5, &found_type_a, found_hash_a);
U8 found_type_b, found_hash_b[64];
Bool found_b = TreeFindEntry(reloaded_tree_content, tlen, name_b, 5, &found_type_b, found_hash_b);

Bool hash_a_match = TRUE, hash_b_match = TRUE;
I64 k;
for (k=0;k<64;k++) { if (found_hash_a[k]!=blob1_hash[k]) hash_a_match=FALSE;
                      if (found_hash_b[k]!=blob2_hash[k]) hash_b_match=FALSE; }

CommPrint(1,"reloaded_type=%d found_a=%d found_b=%d type_a=%d type_b=%d hash_a_match=%d hash_b_match=%d\n",
          reloaded_type, found_a, found_b, found_type_a, found_type_b, hash_a_match, hash_b_match);

if (hok && rcount==3 && vt==3 && vok==3 && reloaded_type==OBJ_TREE &&
    found_a && found_b && found_type_a==OBJ_BLOB && found_type_b==OBJ_BLOB &&
    hash_a_match && hash_b_match)
  CommPrint(1,"PASS tree_object_roundtrip\n");
else
  CommPrint(1,"FAIL tree_object_roundtrip\n");
