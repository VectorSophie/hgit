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
// Tree.HC — tree object content: an entry list mapping name -> child
// object (type + hash). This is what goes in the `data`/`dlen` passed
// to ObjectPut with type=OBJ_TREE - the actual design ADR 0001 and
// FORMAT.md deferred as "not yet designed." Verified end-to-end
// (encode, store via ObjectPut, FileWrite, FileRead, decode, look up
// both entries by name) in experiments/10-tree-object/.
//
// Content format:
//   U32 entry_count
//   repeated entry_count times:
//     U8 name_len
//     name_len bytes of name (flat, single-level - no path separators
//     or nesting handled here; a name is just an arbitrary byte string)
//     U8 child_type   (OBJ_BLOB or OBJ_TREE, see Object.HC)
//     64 bytes child_hash (BLAKE2b-512 content address of the child)
//
// Depends on Canon.HC (PutU32LE/GetU32LE) and Object.HC's OBJ_* tags.

// Appends one entry to a tree-content buffer being built. Caller is
// responsible for writing the U32 entry_count prefix themselves (not
// done here, since it isn't known until all entries are appended) -
// see experiments/10-tree-object/'s test driver for the pattern.
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
// content buffer (tree_buf points at the U32 entry_count, i.e. the
// object's content with the OBJ_TREE type tag byte already stripped)
// and copies its type into *type_out, hash into hash_out (64 bytes).
// Returns FALSE if not found. Linear scan - fine for tiny trees, not
// yet a real index (same caveat as Archive.HC's ArchiveVerify).
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
// Commit.HC — commit object content: a tree reference, zero or more
// parent references, a timestamp, and a message. This is what goes in
// the `data`/`dlen` passed to ObjectPut with type=OBJ_COMMIT - the
// content design ADR 0001/FORMAT.md deferred alongside tree content.
// Verified end-to-end (root commit with 0 parents, child commit with 1
// parent referencing the root, both referencing the same tree) in
// experiments/11-commit-object/.
//
// Content format:
//   64 bytes  tree_hash
//   U8        parent_count
//   repeated parent_count times: 64 bytes parent_hash
//   U64       timestamp LE (seconds; epoch/meaning not yet decided -
//             just an opaque monotonic-ish number so far)
//   U32       message_len LE
//   message_len bytes of message (no encoding assumed - opaque bytes)
//
// No author/identity field yet - that's tied up with the product
// thesis's "stable entity ID" / "human mark" concepts (M3 work per the
// brief's own milestone order), deliberately not invented here.
//
// Depends on Canon.HC (PutU64LE/GetU64LE/PutU32LE/GetU32LE).

U0 CommitEncode(U8 *buf, I64 *len, U8 *tree_hash, U8 *parent_hashes,
                U8 parent_count, U64 timestamp, U8 *message, I64 message_len)
{
  I64 i, j;
  for (i=0; i<64; i++) buf[*len+i] = tree_hash[i];
  *len += 64;
  buf[*len] = parent_count; *len += 1;
  for (i=0; i<parent_count; i++) {
    for (j=0; j<64; j++) buf[*len+j] = parent_hashes[i*64+j];
    *len += 64;
  }
  PutU64LE(buf, *len, timestamp); *len += 8;
  PutU32LE(buf, *len, message_len); *len += 4;
  for (i=0; i<message_len; i++) buf[*len+i] = message[i];
  *len += message_len;
}

// Accessors - all take a pointer to the start of commit content (i.e.
// the object's data with the OBJ_COMMIT type tag byte already
// stripped), matching the convention Tree.HC's TreeFindEntry uses.
U8 *CommitTreeHash(U8 *buf) { return buf; }
U8 CommitParentCount(U8 *buf) { return buf[64]; }
U8 *CommitParentHash(U8 *buf, I64 idx) { return buf + 65 + idx*64; }

U64 CommitTimestamp(U8 *buf)
{
  I64 pos = 65 + CommitParentCount(buf)*64;
  return GetU64LE(buf, pos);
}

U32 CommitMessageLen(U8 *buf)
{
  I64 pos = 65 + CommitParentCount(buf)*64 + 8;
  return GetU32LE(buf, pos);
}

U8 *CommitMessage(U8 *buf)
{
  I64 pos = 65 + CommitParentCount(buf)*64 + 8 + 4;
  return buf + pos;
}
// Index.HC — hash -> offset lookup over a .HGS object section.
//
// The last piece ADR 0001/FORMAT.md flagged as missing: until this,
// nothing could answer "where is the object with this hash" - every
// probe that needed an object's location tracked its offset by hand
// (e.g. `tree_off = alen` right after the ObjectPut call that created
// it). That's fragile: experiments/12-index/ hit a real crash (a
// General Protection fault inside TreeFindEntry) caused by exactly this
// kind of hand-computed offset being wrong by a few bytes after adding
// a header. The fix wasn't patching the arithmetic - it was building
// this and using IndexLookup instead of hand-tracking offsets at all.
//
// IndexBuild does one linear scan (same pattern/cost as
// Archive.HC's ArchiveVerify) and records each record's *stored* hash
// (not recomputed) plus its start offset. IndexLookup is still a linear
// scan over the result - no hash table yet, see "Not yet done" in
// experiments/12-index/README.md. Even without O(1) lookup, this is a
// real capability gain: nothing could look up "the object with this
// hash" at all before this file existed.
//
// Depends on Canon.HC (GetU64LE).

// Scans an archive's object section (NOT including the 16-byte .HGS
// header - pass archive_buf+16 / total_len-16 for a real .HGS file, see
// Hgs.HC), filling out_hashes (count*64 bytes) and out_offsets (count
// I64s, each the byte offset - relative to archive_buf - of that
// record's length field, i.e. the same offset ObjectPut's callers used
// to track by hand).
U0 IndexBuild(U8 *archive_buf, I64 total_len, U8 *out_hashes,
              I64 *out_offsets, I64 *out_count)
{
  I64 pos = 0, n = 0;
  while (pos < total_len) {
    I64 rec_start = pos;
    U64 len = GetU64LE(archive_buf, pos); pos += 8;
    pos += len;
    U8 *stored_hash = archive_buf + pos;
    I64 i;
    for (i=0; i<64; i++) out_hashes[n*64+i] = stored_hash[i];
    out_offsets[n] = rec_start;
    pos += 64;
    n++;
  }
  *out_count = n;
}

// Linear search - fine at hgit's current tiny scale, a real bottleneck
// once corpora grow (see "Not yet done"). Returns the record's offset
// (same convention as IndexBuild's out_offsets) via *offset_out, or
// FALSE if target_hash isn't present.
Bool IndexLookup(U8 *index_hashes, I64 *index_offsets, I64 count,
                  U8 *target_hash, I64 *offset_out)
{
  I64 i, j;
  for (i=0; i<count; i++) {
    Bool same = TRUE;
    for (j=0; j<64; j++) if (index_hashes[i*64+j] != target_hash[j]) same = FALSE;
    if (same) { *offset_out = index_offsets[i]; return TRUE; }
  }
  return FALSE;
}
// Init.HC — `hgit init`: create a new, empty repository.
//
// First real CLI-shaped command (M1) built on the now-complete
// hgit-core storage layer (Canon/Blake2b/Hgs). A repository, at this
// stage, is just a `.HGS` file containing the 16-byte header and zero
// objects - no working-directory scanning, no object creation yet
// (that's `hgit witness`/`hgit offer`, not built here).
//
// Verified (experiments/13-hgit-init/): creates a valid empty repo;
// refuses to overwrite an existing one at the same path rather than
// silently clobbering it - confirmed FileRead returns NULL cleanly for
// a missing file (no exception needed) before relying on that.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC (HgsWriteHeader/HgsReadHeader).

// Returns TRUE on success, FALSE if a file already exists at `path`
// (existing repos/files are never overwritten by init).
Bool HgitInit(U8 *path)
{
  I64 existing_size;
  U8 *existing = FileRead(path, &existing_size);
  if (existing != NULL) return FALSE;
  U8 header[16];
  HgsWriteHeader(header, 1, 0);
  FileWrite(path, header, 16);
  return TRUE;
}
// Head.HC — the "current offering" pointer: hgit's minimal ref/HEAD
// equivalent, unblocking `status`/`offer`/`history` against a real
// prior commit rather than only the empty-repo case (probe 16).
//
// Deliberately minimal for M1: ONE pointer per repository, no named
// paths/branches yet (the brief's `hgit path` commands are explicitly
// M2 work - "paths" - not built here; a single implicit path is enough
// to make `offer`/`history` meaningful). Stored as a sidecar file next
// to the repo (`<repo_path>.head`, exactly 64 bytes: the latest
// commit's hash) rather than inside the `.HGS` file itself - the .HGS
// header's own reserved field is only 2 bytes, nowhere near enough for
// a 64-byte hash, and keeping it as a separate small file means it can
// use plain FileWrite/FileRead with no changes to the archive format.
//
// Verified (experiments/17-head-pointer/): absent on a fresh repo
// (correctly reports "no offerings yet" via HeadRead returning FALSE,
// same NULL-means-absent convention as HgitInit/HgitStatus), settable,
// and independently re-settable to a second value (confirms it's a
// real mutable pointer, not a write-once accident).
//
// Depends only on kernel FileRead/FileWrite - no hgit-core dependency,
// since it doesn't touch the .HGS format itself.

U0 HeadPath(U8 *repo_path, U8 *out_path)
{
  I64 i = 0;
  while (repo_path[i]) { out_path[i] = repo_path[i]; i++; }
  out_path[i++]='.'; out_path[i++]='h'; out_path[i++]='e';
  out_path[i++]='a'; out_path[i++]='d'; out_path[i]=0;
}

// Returns TRUE and fills hash_out (64 bytes) if the repo has a current
// offering; FALSE (hash_out untouched) if it doesn't yet.
Bool HeadRead(U8 *repo_path, U8 *hash_out)
{
  U8 hp[256];
  HeadPath(repo_path, hp);
  I64 size;
  U8 *buf = FileRead(hp, &size);
  if (buf == NULL || size != 64) return FALSE;
  I64 i;
  for (i=0; i<64; i++) hash_out[i] = buf[i];
  return TRUE;
}

// Sets the repo's current offering to `hash` (64 bytes), overwriting
// any previous value.
U0 HeadWrite(U8 *repo_path, U8 *hash)
{
  U8 hp[256];
  HeadPath(repo_path, hp);
  FileWrite(hp, hash, 64);
}
// Offer.HC — `hgit offer`: the actual recording command. This is the
// integration point for the whole object model built so far - the
// first command that creates real objects from real files rather than
// only reading/checking what already exists.
//
// What it does: enumerates files matching `find_mask`, stores each as
// an OBJ_BLOB, builds an OBJ_TREE entry list over them, creates an
// OBJ_COMMIT referencing that tree and the repo's current HEAD (if any)
// as parent, appends all of it to the repo's .HGS file, and points
// HEAD at the new commit. Verified end-to-end, twice in a row - a root
// offering (no parent) and a second offering (parent = the first) with
// a changed file - in experiments/18-hgit-offer/.
//
// Deliberately minimal / not yet done, see that probe's README for the
// full list: no working-copy diffing (every matching file is re-blobbed
// on every offer, not just changed ones - no deduplication awareness at
// this layer, though identical content does still hash-dedupe for free
// since objects are content-addressed), fixed-size local buffers
// (archive[8192], tree_content[2048], per-file blob_tagged[512] - real
// limits, not yet hit by anything tested), and `find_mask` has to be
// passed in rather than "the whole repo directory minus the repo's own
// files" (no self-exclusion logic yet).
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC, Object.HC,
// Tree.HC, Commit.HC (the whole hgit-core object layer) and Head.HC.

U0 HgitOffer(U8 *repo_path, U8 *find_mask, U8 *message, I64 message_len,
             U64 timestamp)
{
  // Load the existing repo's object section into a working buffer.
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  U8 archive[8192];
  I64 alen = 16; // header goes here at the end, once we know the count
  I64 i;
  for (i = 0; i < rsize-16; i++) archive[16+i] = rbuf[16+i];
  alen = rsize;

  // Build blobs + tree from every file matching find_mask.
  U8 tree_content[2048];
  I64 tlen = 4; // leave room for the U32 entry_count, filled in below
  I64 entry_count = 0;

  CDirEntry *tmpde = FilesFind(find_mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 fsize;
    U8 *fbuf = FileRead(tmpde->full_name, &fsize);
    U8 blob_tagged[512];
    blob_tagged[0] = OBJ_BLOB;
    for (i=0; i<fsize; i++) blob_tagged[1+i] = fbuf[i];
    U8 blob_hash[64];
    B2Hash512Any(blob_tagged, fsize+1, blob_hash);
    ObjectPut(archive, &alen, OBJ_BLOB, fbuf, fsize);

    // name = just the filename portion, after the last '/'
    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;
    TreeEncodeEntry(tree_content, &tlen, tmpde->full_name+name_start, name_len,
                     OBJ_BLOB, blob_hash);
    entry_count++;
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
  PutU32LE(tree_content, 0, entry_count);

  I64 tree_content_len = tlen;
  U8 tree_tagged[2048];
  tree_tagged[0] = OBJ_TREE;
  for (i=0; i<tree_content_len; i++) tree_tagged[1+i] = tree_content[i];
  U8 tree_hash[64];
  B2Hash512Any(tree_tagged, tree_content_len+1, tree_hash);
  ObjectPut(archive, &alen, OBJ_TREE, tree_content, tree_content_len);

  // Commit: parent = current HEAD, if any.
  U8 parent_hash[64];
  Bool has_parent = HeadRead(repo_path, parent_hash);
  U8 commit_content[512];
  I64 clen = 0;
  CommitEncode(commit_content, &clen, tree_hash, parent_hash,
               has_parent, timestamp, message, message_len);
  U8 commit_tagged[512];
  commit_tagged[0] = OBJ_COMMIT;
  for (i=0; i<clen; i++) commit_tagged[1+i] = commit_content[i];
  U8 commit_hash[64];
  B2Hash512Any(commit_tagged, clen+1, commit_hash);
  ObjectPut(archive, &alen, OBJ_COMMIT, commit_content, clen);

  // Rewrite the repo with the updated header (new total object count:
  // rcount existing + entry_count blobs + 1 tree + 1 commit).
  HgsWriteHeader(archive, rver, rcount + entry_count + 2);
  FileWrite(repo_path, archive, alen);
  HeadWrite(repo_path, commit_hash);
}
U0 OpLogPath(U8 *repo_path, U8 *out_path)
{
  I64 i = 0;
  while (repo_path[i]) { out_path[i] = repo_path[i]; i++; }
  out_path[i++]='.'; out_path[i++]='o'; out_path[i++]='p';
  out_path[i++]='l'; out_path[i++]='o'; out_path[i++]='g';
  out_path[i] = 0;
}

// Each entry: [U64 timestamp][64 bytes prev_head][64 bytes new_head] = 136 bytes.
U0 OpLogAppend(U8 *repo_path, U8 *prev_head, U8 *new_head, U64 timestamp)
{
  U8 log_path[256];
  OpLogPath(repo_path, log_path);
  I64 old_size;
  U8 *old_buf = FileRead(log_path, &old_size);
  I64 total_old;
  if (old_buf==NULL) total_old = 0; else total_old = old_size;

  U8 new_buf[16384];
  I64 j;
  for (j=0; j<total_old; j++) new_buf[j] = old_buf[j];
  I64 pos = total_old;
  PutU64LE(new_buf, pos, timestamp); pos += 8;
  for (j=0; j<64; j++) new_buf[pos+j] = prev_head[j]; pos += 64;
  for (j=0; j<64; j++) new_buf[pos+j] = new_head[j]; pos += 64;
  FileWrite(log_path, new_buf, pos);
}

// Undoes the last logged operation: restores HEAD to that entry's
// prev_head and removes the entry from the log. Returns FALSE (no
// change) if the log is empty.
Bool OpLogUndo(U8 *repo_path)
{
  U8 log_path[256];
  OpLogPath(repo_path, log_path);
  I64 size;
  U8 *buf = FileRead(log_path, &size);
  if (buf==NULL || size < 136) return FALSE;
  I64 last_off = size - 136;
  U8 *prev_head = buf + last_off + 8;
  HeadWrite(repo_path, prev_head);
  FileWrite(log_path, buf, last_off);
  return TRUE;
}

// --- test: two offerings, each logged, then undo once ---
U8 zero_hash[64];
I64 zi;
for (zi=0; zi<64; zi++) zero_hash[zi] = 0;

HgitInit("C:/Home/OpLogTestRepo.hgs");
U8 fa[3]; fa[0]='o';fa[1]='n';fa[2]='e';
FileWrite("C:/Home/OpLogFileA.txt", fa, 3);

// offer 1 (root commit) - prev is "no head yet", represented as zero_hash
U8 msg1[6]; msg1[0]='f';msg1[1]='i';msg1[2]='r';msg1[3]='s';msg1[4]='t';msg1[5]=0;
HgitOffer("C:/Home/OpLogTestRepo.hgs", "C:/Home/OpLogFileA*", msg1, 5, 1000);
U8 head_after_1[64];
HeadRead("C:/Home/OpLogTestRepo.hgs", head_after_1);
OpLogAppend("C:/Home/OpLogTestRepo.hgs", zero_hash, head_after_1, 1000);

// offer 2 (child commit)
U8 fa2[3]; fa2[0]='t';fa2[1]='w';fa2[2]='o';
FileWrite("C:/Home/OpLogFileA.txt", fa2, 3);
U8 msg2[7]; msg2[0]='s';msg2[1]='e';msg2[2]='c';msg2[3]='o';msg2[4]='n';msg2[5]='d';msg2[6]=0;
HgitOffer("C:/Home/OpLogTestRepo.hgs", "C:/Home/OpLogFileA*", msg2, 6, 2000);
U8 head_after_2[64];
HeadRead("C:/Home/OpLogTestRepo.hgs", head_after_2);
OpLogAppend("C:/Home/OpLogTestRepo.hgs", head_after_1, head_after_2, 2000);

I64 k;
Bool heads_differ = FALSE;
for (k=0;k<64;k++) if (head_after_1[k]!=head_after_2[k]) heads_differ=TRUE;
CommPrint(1, "heads_differ_after_two_offers=%d\n", heads_differ);

// undo once: HEAD should revert to head_after_1
Bool undo_ok = OpLogUndo("C:/Home/OpLogTestRepo.hgs");
U8 head_after_undo[64];
Bool found_after_undo = HeadRead("C:/Home/OpLogTestRepo.hgs", head_after_undo);
Bool matches_head1 = TRUE;
for (k=0;k<64;k++) if (head_after_undo[k]!=head_after_1[k]) matches_head1=FALSE;
CommPrint(1, "undo_ok=%d found_after_undo=%d matches_head1=%d\n", undo_ok, found_after_undo, matches_head1);

// undo again: HEAD should revert to zero_hash (the "no commit" sentinel)
Bool undo_ok2 = OpLogUndo("C:/Home/OpLogTestRepo.hgs");
U8 head_after_undo2[64];
HeadRead("C:/Home/OpLogTestRepo.hgs", head_after_undo2);
Bool matches_zero = TRUE;
for (k=0;k<64;k++) if (head_after_undo2[k]!=zero_hash[k]) matches_zero=FALSE;
CommPrint(1, "undo_ok2=%d matches_zero=%d\n", undo_ok2, matches_zero);

// a third undo should report FALSE (nothing left to undo)
Bool undo_ok3 = OpLogUndo("C:/Home/OpLogTestRepo.hgs");
CommPrint(1, "undo_ok3=%d (expect 0)\n", undo_ok3);

if (heads_differ && undo_ok && found_after_undo && matches_head1 &&
    undo_ok2 && matches_zero && !undo_ok3)
  CommPrint(1, "PASS oplog_undo\n");
else
  CommPrint(1, "FAIL oplog_undo\n");
