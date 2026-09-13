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
// object (type + hash), plus (per ADR 0004) a stable per-entry entity
// ID. This is what goes in the `data`/`dlen` passed to ObjectPut with
// type=OBJ_TREE. Verified end-to-end (encode, store via ObjectPut,
// FileWrite, FileRead, decode, look up both entries by name) in
// experiments/10-tree-object/; the entity ID field added in
// experiments/49-entity-id/.
//
// Content format:
//   U32 entry_count
//   repeated entry_count times:
//     U8 name_len
//     name_len bytes of name (flat, single-level - no path separators
//     or nesting handled here; a name is just an arbitrary byte string)
//     U8 child_type   (OBJ_BLOB or OBJ_TREE, see Object.HC)
//     64 bytes child_hash (BLAKE2b-512 content address of the child)
//     8 bytes entity_id (U64, LE) — a stable identifier for "this
//       tracked name," independent of content. Per ADR 0004: generated
//       fresh (two RandU32 reads) the first time a name appears in any
//       tree this repo has built, and copied forward unchanged into
//       every later tree that still has an entry for that name -
//       Offer.HC is what actually does the carrying-forward, by
//       looking up the previous tree before building the new one.
//       Deliberately minimal: same name = same identity; an actual
//       rename (name change) is NOT detected and gets a fresh ID, see
//       ADR 0004's "What this slice does not do."
//
// Depends on Canon.HC (PutU32LE/GetU32LE/PutU64LE/GetU64LE) and
// Object.HC's OBJ_* tags.

// Combines two RandU32 reads into a random 64-bit entity ID. RandU32
// confirmed real and usable on real TempleOS in experiments/48-rand-for-identity/
// (both from primary source usage - a real filesystem serial number -
// and empirically: three successive reads returned distinct values).
U64 GenerateEntityId()
{
  U32 a = RandU32;
  U32 b = RandU32;
  return (a(U64) << 32) | b(U64);
}

// Appends one entry to a tree-content buffer being built. Caller is
// responsible for writing the U32 entry_count prefix themselves (not
// done here, since it isn't known until all entries are appended) -
// see experiments/10-tree-object/'s test driver for the pattern.
U0 TreeEncodeEntry(U8 *buf, I64 *len, U8 *name, I64 name_len,
                    U8 child_type, U8 *child_hash, U64 entity_id)
{
  I64 i;
  buf[*len] = name_len; *len += 1;
  for (i=0; i<name_len; i++) buf[*len+i] = name[i];
  *len += name_len;
  buf[*len] = child_type; *len += 1;
  for (i=0; i<64; i++) buf[*len+i] = child_hash[i];
  *len += 64;
  PutU64LE(buf, *len, entity_id); *len += 8;
}

// Finds the entry named `name` (name_len bytes) inside a decoded tree
// content buffer (tree_buf points at the U32 entry_count, i.e. the
// object's content with the OBJ_TREE type tag byte already stripped)
// and copies its type into *type_out, hash into hash_out (64 bytes),
// and entity ID into *entity_id_out. Returns FALSE if not found.
// Linear scan - fine for tiny trees, not yet a real index (same
// caveat as Archive.HC's ArchiveVerify).
Bool TreeFindEntry(U8 *tree_buf, I64 tree_len, U8 *name, I64 name_len,
                    U8 *type_out, U8 *hash_out, U64 *entity_id_out)
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
    U64 this_entity_id = GetU64LE(tree_buf, pos+this_name_len+1+64);
    if (same) {
      *type_out = this_type;
      for (i=0; i<64; i++) hash_out[i] = this_hash[i];
      *entity_id_out = this_entity_id;
      return TRUE;
    }
    pos += this_name_len + 1 + 64 + 8;
  }
  return FALSE;
}
// Commit.HC — commit object content: a tree reference, zero or more
// parent references, a timestamp, a message, and (per ADR 0005) an
// optional typed relation to an earlier commit. This is what goes in
// the `data`/`dlen` passed to ObjectPut with type=OBJ_COMMIT - the
// content design ADR 0001/FORMAT.md deferred alongside tree content.
// Verified end-to-end (root commit with 0 parents, child commit with 1
// parent referencing the root, both referencing the same tree) in
// experiments/11-commit-object/; the relation fields verified in
// experiments/50-relation-vocabulary/.
//
// Content format:
//   64 bytes  tree_hash
//   U8        parent_count
//   repeated parent_count times: 64 bytes parent_hash
//   U64       timestamp LE (seconds; epoch/meaning not yet decided -
//             just an opaque monotonic-ish number so far)
//   U32       message_len LE
//   message_len bytes of message (no encoding assumed - opaque bytes)
//   U8        relation_tag (0=none/plain continuation, 1=CONTINUES
//             explicit, 2=CORRECTS, 3=REVERTS, 4=RECONCILES)
//   if relation_tag != 0: 64 bytes relation_target_hash (the prior
//             commit this relation names - not necessarily the parent;
//             a correction can name a commit further back)
//
// The relation fields are placed AFTER the message deliberately: every
// accessor that reads UP TO the message (CommitTimestamp/
// CommitMessageLen/CommitMessage) keeps its existing offset math
// unchanged. Anything reading the relation fields recomputes from
// CommitMessageLen instead of assuming a fixed offset.
//
// Stable entity identity (ADR 0004, Tree.HC's per-entry entity_id) is
// a separate concern from this file - this ADR (0005) does NOT yet
// scope a relation to a specific entity within a commit, only to
// another commit as a whole. See ADR 0005's own "what this slice does
// not do."
//
// Depends on Canon.HC (PutU64LE/GetU64LE/PutU32LE/GetU32LE).

#define REL_NONE      0
#define REL_CONTINUES 1
#define REL_CORRECTS  2
#define REL_REVERTS   3
#define REL_RECONCILES 4

// `relation_tag`/`relation_target` may be REL_NONE/NULL for an
// ordinary commit with no explicit relation (the common case - costs
// exactly one byte).
U0 CommitEncode(U8 *buf, I64 *len, U8 *tree_hash, U8 *parent_hashes,
                U8 parent_count, U64 timestamp, U8 *message, I64 message_len,
                U8 relation_tag, U8 *relation_target)
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

  buf[*len] = relation_tag; *len += 1;
  if (relation_tag != REL_NONE) {
    for (i=0; i<64; i++) buf[*len+i] = relation_target[i];
    *len += 64;
  }
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

// Byte offset (relative to `buf`) of the relation_tag field - shared
// by both relation accessors below, so the "recompute, don't assume a
// fixed offset" rule from this file's own header comment lives in
// exactly one place.
I64 CommitRelationOffset(U8 *buf)
{
  I64 pos = 65 + CommitParentCount(buf)*64 + 8 + 4 + CommitMessageLen(buf);
  return pos;
}

U8 CommitRelationTag(U8 *buf)
{
  return buf[CommitRelationOffset(buf)];
}

// Only valid to call if CommitRelationTag(buf) != REL_NONE - returns a
// pointer to the 64-byte target hash.
U8 *CommitRelationTarget(U8 *buf)
{
  return buf + CommitRelationOffset(buf) + 1;
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
// Meta.HC — the combined per-repo metadata file, per ADR 0003
// (docs/adr/0003-path-length-ceiling.md).
//
// Real TempleOS/RedSea constraint found in probe 36
// (experiments/36-path-scoped-oplog/): a full path string longer than
// 33 characters is silently rejected by FileWrite/FileRead - no error,
// the call just no-ops. Every sidecar-file-per-concern this project
// built before this (Head.HC's `.head.<name>`, Paths.HC's `.paths`/
// `.currentpath`, OpLog.HC's `.ol.<name>`/`.rl.<name>`) grows its own
// filename with the path name, shrinking the safe budget every time a
// new per-path concern is added.
//
// One combined file per repo, `<repo_path>.m` - a single short, FIXED
// suffix that never grows no matter how many paths exist or how long
// their names are, because path names live INSIDE the file's own
// structure as data, not in filenames as identity.
//
// Probe 40 built and verified the HEAD-storage slice alone
// (MetaReadHead/MetaWriteHead). Probe 41 added path declaration/listing
// (MetaPathExists/MetaPathDeclare/MetaPathList) and the current-path
// pointer (MetaCurrentGet/MetaCurrentSet). Probe 42 adds the operation
// log (MetaOpLogAppend/MetaOpLogPopLast) - now every concern
// Paths.HC's and OpLog.HC's sidecar files used to hold lives in this
// one file too. Deliberately NOT yet wired in: Head.HC/Paths.HC/
// OpLog.HC and every real hgit command still use today's separate-
// sidecar-file layout - same incremental pattern this project already
// used for OpLog.HC itself (built standalone in probe 30, wired into
// Offer.HC in probe 31).
//
// Depends on Canon.HC (PutU64LE/GetU64LE, for the operation-log entry
// slice only) - load it first.
//
// Record format (flat, read-until-EOF, same style as Paths.HC's
// `.paths` file):
//   U8  name_len     (0 for a "global," not-per-path record, e.g. the
//                      current-path pointer)
//   name_len bytes of path name
//   U8  tag
//   U8  payload_len
//   payload_len bytes of payload
//
// Tags:
//   META_TAG_HEAD          - payload is the path's 64-byte HEAD hash
//   META_TAG_PATH_DECLARED - marks a (non-"main") path name as
//                            existing; payload_len 0, no payload -
//                            the record's own name IS the data
//   META_TAG_CURRENT       - name_len 0 (global); payload is the
//                            current path's name bytes
//
// Every "set" operation splices out any existing record for the same
// (name, tag) before appending the new one (MetaSpliceOut) - so each
// (name, tag) pair has at most one record at a time, not an
// ever-growing history. MetaFind (last-match-wins scan) and
// MetaAppendRecord are the two shared primitives every public
// function below is built from.

#define META_TAG_HEAD 1
#define META_TAG_PATH_DECLARED 2
#define META_TAG_CURRENT 3

// Kept self-contained (hgit-core shouldn't depend on hgit-cli's
// Paths.HC) even though it matches Paths.HC's own HGIT_MAX_PATH_NAME.
#define META_MAX_PATH_NAME 64

U0 MetaPath(U8 *repo_path, U8 *out_path)
{
  I64 i = 0;
  while (repo_path[i]) { out_path[i] = repo_path[i]; i++; }
  out_path[i++] = '.'; out_path[i++] = 'm';
  out_path[i] = 0;
}

// Scans buf (size bytes) for the LAST record matching (name, tag).
// Returns the payload's byte OFFSET within buf (so the caller computes
// `buf + offset` itself - avoids a pointer-to-pointer out-parameter,
// a syntax shape not used/verified anywhere else in this project) and
// sets *payload_len_out to its length. Returns -1 (payload_len_out
// untouched) if nothing matches.
I64 MetaFind(U8 *buf, I64 size, U8 *name, U8 tag, I64 *payload_len_out)
{
  I64 target_len = StrLen(name);
  I64 pos = 0;
  I64 found_off = -1;
  while (pos < size) {
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 rtag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    I64 payload_off = pos; pos += payload_len;

    if (rtag == tag && name_len == target_len) {
      Bool same = TRUE;
      I64 fi;
      for (fi=0; fi<name_len; fi++) if (rec_name[fi] != name[fi]) same = FALSE;
      if (same) {
        found_off = payload_off;
        *payload_len_out = payload_len;
        // keep scanning - last match wins (splice-on-write should
        // keep this to one, but cheap insurance against a stale dup).
      }
    }
  }
  return found_off;
}

// Copies every record from buf (size bytes) EXCEPT ones matching
// (name, tag) into out_buf. Sets *out_len to the copied length.
U0 MetaSpliceOut(U8 *buf, I64 size, U8 *name, U8 tag, U8 *out_buf, I64 *out_len)
{
  I64 target_len = StrLen(name);
  I64 pos = 0, new_len = 0;
  while (pos < size) {
    I64 entry_start = pos;
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 rtag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    pos += payload_len;

    Bool is_match = FALSE;
    if (rtag == tag && name_len == target_len) {
      Bool same = TRUE;
      I64 si;
      for (si=0; si<name_len; si++) if (rec_name[si] != name[si]) same = FALSE;
      is_match = same;
    }
    if (!is_match) {
      I64 entry_len = pos - entry_start;
      I64 ci;
      for (ci=0; ci<entry_len; ci++) out_buf[new_len+ci] = buf[entry_start+ci];
      new_len += entry_len;
    }
  }
  *out_len = new_len;
}

// Appends one record (name, tag, payload) to buf at *len, advancing it.
U0 MetaAppendRecord(U8 *buf, I64 *len, U8 *name, U8 tag, U8 *payload, U8 payload_len)
{
  I64 name_len = StrLen(name);
  I64 pos = *len;
  buf[pos] = name_len; pos += 1;
  I64 ai;
  for (ai=0; ai<name_len; ai++) buf[pos+ai] = name[ai];
  pos += name_len;
  buf[pos] = tag; pos += 1;
  buf[pos] = payload_len; pos += 1;
  for (ai=0; ai<payload_len; ai++) buf[pos+ai] = payload[ai];
  pos += payload_len;
  *len = pos;
}

// Reads the current HEAD hash (64 bytes) recorded for path `name`.
// Returns FALSE if no such record exists yet (same convention as
// Head.HC's HeadRead/Paths.HC's CurrentHeadRead).
Bool MetaReadHead(U8 *repo_path, U8 *name, U8 *hash_out)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return FALSE;

  I64 payload_len;
  I64 payload_off = MetaFind(buf, size, name, META_TAG_HEAD, &payload_len);
  if (payload_off < 0) return FALSE;
  I64 i;
  for (i=0; i<64; i++) hash_out[i] = buf[payload_off+i];
  return TRUE;
}

// Sets path `name`'s HEAD to `hash` (64 bytes), replacing any existing
// HEAD record for that name.
U0 MetaWriteHead(U8 *repo_path, U8 *name, U8 *hash)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 total_old;
  if (buf == NULL) total_old = 0; else total_old = size;

  U8 new_buf[16384]; // fixed cap for now - same style as OpLog.HC
  I64 new_len;
  MetaSpliceOut(buf, total_old, name, META_TAG_HEAD, new_buf, &new_len);
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_HEAD, hash, 64);
  FileWrite(meta_path, new_buf, new_len);
}

// TRUE if `name` is "main" (always exists, never stored) or has a
// META_TAG_PATH_DECLARED record.
Bool MetaPathExists(U8 *repo_path, U8 *name)
{
  if (StrCmp(name, "main") == 0) return TRUE;
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return FALSE;
  I64 payload_len;
  return MetaFind(buf, size, name, META_TAG_PATH_DECLARED, &payload_len) >= 0;
}

// Declares `name` as an existing path (idempotent - does nothing if
// already declared or if `name` is "main").
U0 MetaPathDeclare(U8 *repo_path, U8 *name)
{
  if (MetaPathExists(repo_path, name)) return;
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 total_old;
  if (buf == NULL) total_old = 0; else total_old = size;

  U8 new_buf[16384];
  I64 new_len = 0;
  I64 i;
  for (i=0; i<total_old; i++) new_buf[i] = buf[i];
  new_len = total_old;
  U8 no_payload[1];
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_PATH_DECLARED, no_payload, 0);
  FileWrite(meta_path, new_buf, new_len);
}

// Un-declares `name` (removes its META_TAG_PATH_DECLARED record, if
// any). Does nothing for "main" (can never be undeclared) or a name
// that was never declared. Does NOT touch its HEAD or operation-log
// records - those become orphaned but unreachable via
// MetaPathExists/MetaPathList, the same "left behind, not deleted"
// choice Paths.HC's original PathClose made for its own sidecar files.
U0 MetaPathUndeclare(U8 *repo_path, U8 *name)
{
  if (StrCmp(name, "main") == 0) return;
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return;
  U8 new_buf[16384];
  I64 new_len;
  MetaSpliceOut(buf, size, name, META_TAG_PATH_DECLARED, new_buf, &new_len);
  FileWrite(meta_path, new_buf, new_len);
}

// Prints every path name, "main" first, then each META_TAG_PATH_DECLARED
// record found (creation order).
U0 MetaPathList(U8 *repo_path)
{
  CommPrint(1, "PATH main\n");
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return;
  I64 pos = 0;
  while (pos < size) {
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 rec_tag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    pos += payload_len;
    if (rec_tag == META_TAG_PATH_DECLARED) {
      U8 name_buf[META_MAX_PATH_NAME];
      I64 ni; // NOT "pi" - TempleOS predefines that as the F64 constant
               // pi (confirmed, probe 41): a local var named pi produces
               // a cryptic "Expecting '*' at INT:400921FB54442D18 (F64)"
               // parse error (that hex IS pi's IEEE754 bit pattern).
      for (ni=0; ni<name_len; ni++) name_buf[ni] = rec_name[ni];
      name_buf[name_len] = 0;
      CommPrint(1, "PATH %s\n", name_buf);
    }
  }
}

// Writes out_name = the current path's name (defaults to "main" if no
// META_TAG_CURRENT record exists yet - same convention as Paths.HC's
// CurrentPathGet).
U0 MetaCurrentGet(U8 *repo_path, U8 *out_name)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 payload_len;
  I64 payload_off = -1;
  if (buf != NULL) payload_off = MetaFind(buf, size, "", META_TAG_CURRENT, &payload_len);
  if (payload_off < 0) {
    out_name[0]='m'; out_name[1]='a'; out_name[2]='i'; out_name[3]='n'; out_name[4]=0;
    return;
  }
  I64 i;
  for (i=0; i<payload_len; i++) out_name[i] = buf[payload_off+i];
  out_name[payload_len] = 0;
}

// Sets the current path to `name`, replacing any existing
// META_TAG_CURRENT record.
U0 MetaCurrentSet(U8 *repo_path, U8 *name)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 total_old;
  if (buf == NULL) total_old = 0; else total_old = size;

  U8 new_buf[16384];
  I64 new_len;
  MetaSpliceOut(buf, total_old, "", META_TAG_CURRENT, new_buf, &new_len);
  MetaAppendRecord(new_buf, &new_len, "", META_TAG_CURRENT, name, StrLen(name));
  FileWrite(meta_path, new_buf, new_len);
}

// --- Operation log (probe 42) ---
//
// Unlike HEAD/CURRENT (one record per name, replaced on every write),
// operation-log entries for a path ACCUMULATE - each real operation
// (e.g. an offer) appends one, and undo pops the most recently
// appended one. This needs a different removal primitive from
// MetaSpliceOut (which strips EVERY matching record): MetaSpliceOutLast
// finds and removes only the LAST matching record, leaving earlier
// same-(name,tag) entries alone. Each entry is 136 bytes, the same
// shape OpLog.HC's sidecar-file version already uses and verified
// (probe 30): U64 timestamp + 64-byte prev_head + 64-byte new_head.

#define META_TAG_OPLOG 4

// Finds the LAST record matching (name, tag), copies its payload into
// payload_out (caller-sized buffer) and its length into
// *payload_len_out, and writes every OTHER record (including earlier
// same-name/tag ones) into out_buf/*out_len - i.e. removes exactly one
// occurrence, not all of them. Returns FALSE (out_buf just a copy of
// buf, payload_out untouched) if no match exists.
Bool MetaSpliceOutLast(U8 *buf, I64 size, U8 *name, U8 tag,
                        U8 *out_buf, I64 *out_len,
                        U8 *payload_out, I64 *payload_len_out)
{
  I64 target_len = StrLen(name);
  I64 pos = 0;
  I64 match_start = -1, match_end = -1, match_payload_off = -1, match_payload_len = 0;
  while (pos < size) {
    I64 entry_start = pos;
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 rtag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    I64 payload_off = pos; pos += payload_len;

    if (rtag == tag && name_len == target_len) {
      Bool same = TRUE;
      I64 li;
      for (li=0; li<name_len; li++) if (rec_name[li] != name[li]) same = FALSE;
      if (same) {
        match_start = entry_start;
        match_end = pos;
        match_payload_off = payload_off;
        match_payload_len = payload_len;
      }
    }
  }
  if (match_start < 0) {
    I64 zi;
    for (zi=0; zi<size; zi++) out_buf[zi] = buf[zi];
    *out_len = size;
    return FALSE;
  }
  I64 pli;
  for (pli=0; pli<match_payload_len; pli++) payload_out[pli] = buf[match_payload_off+pli];
  *payload_len_out = match_payload_len;

  I64 new_len = 0, ci;
  for (ci=0; ci<match_start; ci++) out_buf[new_len++] = buf[ci];
  for (ci=match_end; ci<size; ci++) out_buf[new_len++] = buf[ci];
  *out_len = new_len;
  return TRUE;
}

// Appends one 136-byte operation-log entry for path `name`.
U0 MetaOpLogAppend(U8 *repo_path, U8 *name, U8 *prev_head, U8 *new_head, U64 timestamp)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 total_old;
  if (buf == NULL) total_old = 0; else total_old = size;

  U8 payload[136];
  PutU64LE(payload, 0, timestamp);
  I64 bi;
  for (bi=0; bi<64; bi++) payload[8+bi] = prev_head[bi];
  for (bi=0; bi<64; bi++) payload[72+bi] = new_head[bi];

  U8 new_buf[16384];
  I64 new_len = 0;
  for (bi=0; bi<total_old; bi++) new_buf[bi] = buf[bi];
  new_len = total_old;
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_OPLOG, payload, 136);
  FileWrite(meta_path, new_buf, new_len);
}

// Pops the most recently appended operation-log entry for path `name`:
// removes it and returns its prev_head/new_head/timestamp. Returns
// FALSE (outputs untouched) if there's nothing to pop.
Bool MetaOpLogPopLast(U8 *repo_path, U8 *name, U8 *prev_head_out, U8 *new_head_out, U64 *timestamp_out)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return FALSE;

  U8 new_buf[16384];
  I64 new_len;
  U8 payload[136];
  I64 payload_len;
  Bool found = MetaSpliceOutLast(buf, size, name, META_TAG_OPLOG, new_buf, &new_len, payload, &payload_len);
  if (!found) return FALSE;

  *timestamp_out = GetU64LE(payload, 0);
  I64 bi;
  for (bi=0; bi<64; bi++) prev_head_out[bi] = payload[8+bi];
  for (bi=0; bi<64; bi++) new_head_out[bi] = payload[72+bi];

  FileWrite(meta_path, new_buf, new_len);
  return TRUE;
}

// Returns TRUE and fills prev/new/timestamp for the entry at `index`
// (0-based, oldest first) among path `name`'s operation-log entries.
// FALSE if out of range. Read-only. Deliberately returns raw fields,
// not a printable string - hgit-core (this file) shouldn't depend on
// hgit-cli's hex-conversion helpers; callers building a human-readable
// listing do that themselves (see OpLog.HC's OpLogHistory).
Bool MetaOpLogGet(U8 *repo_path, U8 *name, I64 index, U8 *prev_out, U8 *new_out, U64 *timestamp_out)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return FALSE;
  I64 target_len = StrLen(name);
  I64 pos = 0, idx = 0;
  while (pos < size) {
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 tag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    I64 payload_off = pos; pos += payload_len;
    if (tag == META_TAG_OPLOG && name_len == target_len) {
      Bool same = TRUE;
      I64 gi;
      for (gi=0; gi<name_len; gi++) if (rec_name[gi] != name[gi]) same = FALSE;
      if (same) {
        if (idx == index) {
          *timestamp_out = GetU64LE(buf, payload_off);
          I64 bi;
          for (bi=0; bi<64; bi++) prev_out[bi] = buf[payload_off+8+bi];
          for (bi=0; bi<64; bi++) new_out[bi] = buf[payload_off+72+bi];
          return TRUE;
        }
        idx++;
      }
    }
  }
  return FALSE;
}

// Count of operation-log entries for path `name`.
I64 MetaOpLogCount(U8 *repo_path, U8 *name)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return 0;
  I64 target_len = StrLen(name);
  I64 pos = 0, count = 0;
  while (pos < size) {
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 tag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    pos += payload_len;
    if (tag == META_TAG_OPLOG && name_len == target_len) {
      Bool same = TRUE;
      I64 ki;
      for (ki=0; ki<name_len; ki++) if (rec_name[ki] != name[ki]) same = FALSE;
      if (same) count++;
    }
  }
  return count;
}

// --- Redo log: same accumulate/pop-last shape as the operation log
// above, kept as a separate tag rather than reusing META_TAG_OPLOG so
// the two never collide when scanned. OpLog.HC's own OpLogAppend is
// responsible for calling MetaRedoLogClear (a real new operation
// invalidates whatever was undone) - deliberately NOT done
// automatically inside MetaOpLogAppend itself, since OpLogRedo also
// calls MetaOpLogAppend (to push a redone entry back onto the undo
// log) and must NOT clear the remaining redo log as a side effect of
// that internal reuse.

#define META_TAG_REDOLOG 5

U0 MetaRedoLogAppend(U8 *repo_path, U8 *name, U8 *prev_head, U8 *new_head, U64 timestamp)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 total_old;
  if (buf == NULL) total_old = 0; else total_old = size;

  U8 payload[136];
  PutU64LE(payload, 0, timestamp);
  I64 bi;
  for (bi=0; bi<64; bi++) payload[8+bi] = prev_head[bi];
  for (bi=0; bi<64; bi++) payload[72+bi] = new_head[bi];

  U8 new_buf[16384];
  I64 new_len = 0;
  for (bi=0; bi<total_old; bi++) new_buf[bi] = buf[bi];
  new_len = total_old;
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_REDOLOG, payload, 136);
  FileWrite(meta_path, new_buf, new_len);
}

Bool MetaRedoLogPopLast(U8 *repo_path, U8 *name, U8 *prev_head_out, U8 *new_head_out, U64 *timestamp_out)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return FALSE;

  U8 new_buf[16384];
  I64 new_len;
  U8 payload[136];
  I64 payload_len;
  Bool found = MetaSpliceOutLast(buf, size, name, META_TAG_REDOLOG, new_buf, &new_len, payload, &payload_len);
  if (!found) return FALSE;

  *timestamp_out = GetU64LE(payload, 0);
  I64 bi;
  for (bi=0; bi<64; bi++) prev_head_out[bi] = payload[8+bi];
  for (bi=0; bi<64; bi++) new_head_out[bi] = payload[72+bi];

  FileWrite(meta_path, new_buf, new_len);
  return TRUE;
}

// Clears every redo-log entry for path `name` (standard undo/redo
// semantics: a real new operation invalidates whatever was undone).
U0 MetaRedoLogClear(U8 *repo_path, U8 *name)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return;
  U8 new_buf[16384];
  I64 new_len;
  MetaSpliceOut(buf, size, name, META_TAG_REDOLOG, new_buf, &new_len);
  FileWrite(meta_path, new_buf, new_len);
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
// Paths.HC — named paths (hgit's branch equivalent), per the brief's
// `hgit path list/new/go/close` vocabulary.
//
// Probe 43: this file's PUBLIC API (CurrentPathGet/PathExists/
// PathListPrint/PathNew/PathGo/CurrentHeadRead/CurrentHeadWrite/
// PathClose) is now backed by `src/hgit-core/Meta.HC`'s combined
// per-repo metadata file (ADR 0003) internally - every function's
// SIGNATURE and observable behavior is unchanged from probes 34/35/37,
// so Hgit.HC/Offer.HC/History.HC/Status.HC (every real caller) needed
// no changes at all. This retires the old one-sidecar-file-per-concern
// scheme (`.head.<name>`, `.paths`, `.currentpath`) that motivated ADR
// 0003 in the first place - the real path-length ceiling those files
// were vulnerable to (probe 36) no longer applies to path names at
// all, since names now live inside Meta.HC's one combined file rather
// than in filenames.
//
// `PathNameFits` is kept (same name, same call site in PathNew) but
// its actual constraint changed: under the old scheme it had to budget
// for `repo_path + ".head." + name`; under Meta.HC it only needs
// `repo_path + ".m"` to fit - `name` no longer affects any filename at
// all, so long path names that used to be rejected are now accepted.
//
// Depends on Meta.HC (MetaPathExists/MetaPathDeclare/MetaPathUndeclare/
// MetaPathList/MetaCurrentGet/MetaCurrentSet/MetaReadHead/MetaWriteHead)
// and, transitively, Canon.HC. Load Meta.HC first.

#define HGIT_MAX_PATH_NAME 64

// The real, previously-undocumented TempleOS/RedSea limit found in
// probe 36: a full path string longer than this is silently rejected
// by FileWrite/FileRead - no error, the call just no-ops.
#define HGIT_MAX_SAFE_PATH_LEN 33

// TRUE if the combined metadata file itself (`<repo_path>.m`, from
// Meta.HC's MetaPath) would stay at or under HGIT_MAX_SAFE_PATH_LEN.
// `name` no longer affects this at all under the Meta.HC design (kept
// as a parameter only so PathNew's call site is unchanged) - unlike
// the old per-path-sidecar scheme, a long path NAME is never rejected
// by this check anymore, only a long REPO path would be.
Bool PathNameFits(U8 *repo_path, U8 *name)
{
  return StrLen(repo_path) + 2 <= HGIT_MAX_SAFE_PATH_LEN;
}

// Writes out_name = the current path's name (defaults to "main").
U0 CurrentPathGet(U8 *repo_path, U8 *out_name)
{
  MetaCurrentGet(repo_path, out_name);
}

// TRUE if `name` is "main" or has been declared via PathNew.
Bool PathExists(U8 *repo_path, U8 *name)
{
  return MetaPathExists(repo_path, name);
}

// Prints every path name, "main" first, then each declared path.
U0 PathListPrint(U8 *repo_path)
{
  MetaPathList(repo_path);
}

// Creates a new path named `name`, pointing its HEAD at whatever the
// CURRENT path's HEAD is right now (all-zero if the current path has
// no offerings yet). Returns FALSE if `name` already exists (including
// "main"), is too long, or would push the combined metadata file's own
// path past the safe limit (see PathNameFits above).
Bool PathNew(U8 *repo_path, U8 *name)
{
  I64 name_len = StrLen(name);
  if (name_len <= 0 || name_len >= HGIT_MAX_PATH_NAME) return FALSE;
  if (!PathNameFits(repo_path, name)) return FALSE;
  if (MetaPathExists(repo_path, name)) return FALSE;

  U8 cur_name[HGIT_MAX_PATH_NAME];
  MetaCurrentGet(repo_path, cur_name);
  U8 head[64];
  Bool has_head = MetaReadHead(repo_path, cur_name, head);
  if (!has_head) {
    I64 zi;
    for (zi=0; zi<64; zi++) head[zi] = 0;
  }

  MetaWriteHead(repo_path, name, head);
  MetaPathDeclare(repo_path, name);
  return TRUE;
}

// Switches the current path to `name`. Returns FALSE if `name` doesn't
// exist (callers should create it with PathNew first).
Bool PathGo(U8 *repo_path, U8 *name)
{
  if (!MetaPathExists(repo_path, name)) return FALSE;
  MetaCurrentSet(repo_path, name);
  return TRUE;
}

// Reads HEAD for whichever path is CURRENT right now.
Bool CurrentHeadRead(U8 *repo_path, U8 *hash_out)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  MetaCurrentGet(repo_path, cur_name);
  return MetaReadHead(repo_path, cur_name, hash_out);
}

// Writes HEAD for whichever path is CURRENT right now.
U0 CurrentHeadWrite(U8 *repo_path, U8 *hash)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  MetaCurrentGet(repo_path, cur_name);
  MetaWriteHead(repo_path, cur_name, hash);
}

// Removes `name` (its HEAD/operation-log records are left behind,
// orphaned but unreachable - same choice the pre-Meta.HC version made
// for its own sidecar files). If the closed path was current, switches
// current back to "main". Refuses to close "main" itself or a path
// that doesn't exist.
Bool PathClose(U8 *repo_path, U8 *name)
{
  if (StrCmp(name, "main") == 0) return FALSE;
  if (!MetaPathExists(repo_path, name)) return FALSE;
  MetaPathUndeclare(repo_path, name);

  U8 cur_name[HGIT_MAX_PATH_NAME];
  MetaCurrentGet(repo_path, cur_name);
  if (StrCmp(cur_name, name) == 0) {
    MetaCurrentSet(repo_path, "main");
  }
  return TRUE;
}
// WorkDir.HC — working-directory enumeration, for `hgit status`/
// `hgit witness`. First use of TempleOS's real filesystem enumeration
// API (`FilesFind`/`CDirEntry`), confirmed from primary source
// (`Kernel/BlkDev/DskFind.HC`, `Adam/Opt/Utils/DocUtils.HC` in the real
// cia-foundation/TempleOS mirror) before writing this, then verified
// running (experiments/15-dir-enumeration/): lists every file in the
// current directory with correct name and size, including the special
// `.`/`..` entries a caller must filter out.
//
// No dependencies beyond kernel built-ins (FilesFind, CDirEntry,
// DirTreeDel).

// Prints every entry FilesFind("*", 0) returns (including `.`/`..` -
// callers that care should skip names ending in exactly "." or "..").
// This is a placeholder "status"-shaped listing, not real status logic
// yet - no comparison against any recorded tree, just "what's here."
//
// Uses CommPrint (COM1), matching exactly what was tested - this was
// verified via the same host-visible-log convention every other probe
// uses, not via screen output. Switch to Print() for real interactive
// use once this is wired into an actual command, but that specific
// substitution has not itself been tested.
//
// The initial test (experiments/15-dir-enumeration/) ran this loop as a
// bare top-level statement and worked, but per the standing project
// rule (doc 01, probe 05's crash-causing quirk) bare top-level loops
// with local declarations can silently misbehave. This function-
// wrapped form was written as the safer, rule-following version and
// then independently re-verified (not just assumed equivalent) with an
// identical result - see experiments/15-dir-enumeration/README.md.
U0 WorkDirList()
{
  CDirEntry *tmpde = FilesFind("*", 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    CommPrint(1, "%s  %d\n", tmpde->full_name, tmpde->size);
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
}
// Status.HC — `hgit status`: compare the working directory against
// HEAD's tree.
//
// Three cases, all verified:
//   - Zero-offering repo (probe 16): every working-directory file is
//     untracked by definition - lists them via WorkDir.HC's
//     WorkDirList.
//   - Repo with a real HEAD (probe 20): walks HEAD -> its commit -> its
//     tree via Index.HC, then for each file matching `find_mask`,
//     hashes its current content and looks up the same name in the
//     tree's entry list (Tree.HC's TreeFindEntry) to classify it as
//     NEW (not in the tree), MODIFIED (in the tree, hash differs), or
//     UNCHANGED (in the tree, hash matches).
//   - Deleted files (probe 21): walks every entry in HEAD's tree and
//     checks whether a file by that name still exists under
//     `dir_prefix` on disk - if not, reports it DELETED. This needed
//     its own pass over the tree's entries (not just name lookups),
//     since nothing else builds a full listing of "everything the tree
//     says should exist."
//
// `find_mask`/`dir_prefix` exist for the same reason Offer.HC takes a
// mask: no self-exclusion logic yet, so the caller aims them away from
// the repo's own `.hgs`/`.head` files. `dir_prefix` must be the literal
// directory portion of `find_mask` (e.g. "C:/Home/" for
// "C:/Home/OfferFile*") - not derived automatically here.
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC, Object.HC,
// Tree.HC, Commit.HC, Index.HC, Head.HC, WorkDir.HC (the whole
// hgit-core object layer plus the CLI pieces built so far).
//
// Both tree-entry walks (TreeFindEntry's new signature, and the manual
// pass-2 walk below) updated for ADR 0004's 8-byte entity ID field
// (experiments/49-entity-id/).

U0 HgitStatus(U8 *repo_path, U8 *find_mask, U8 *dir_prefix)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "STATUS_ERR not_a_repository %s\n", repo_path); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "STATUS_ERR bad_header %s\n", repo_path); return; }

  if (rcount == 0) {
    CommPrint(1, "STATUS_NO_OFFERINGS_YET\n");
    WorkDirList();
    return;
  }

  U8 head_hash[64];
  if (!CurrentHeadRead(repo_path, head_hash)) {
    CommPrint(1, "STATUS_ERR no_head_but_objects_exist\n");
    return;
  }

  U8 idx_hashes[64*64];
  I64 idx_offsets[64];
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 commit_off_rel;
  IndexLookup(idx_hashes, idx_offsets, idx_count, head_hash, &commit_off_rel);
  I64 commit_off = 16 + commit_off_rel; // Index offsets are relative to
                                        // the object section (rbuf+16)
                                        // - see probe 12/19's lesson.
  U8 *commit_content = rbuf + commit_off + 9;
  U8 *tree_hash = CommitTreeHash(commit_content);

  I64 tree_off_rel;
  IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &tree_off_rel);
  I64 tree_off = 16 + tree_off_rel;
  U64 tree_record_len = GetU64LE(rbuf, tree_off);
  U8 *tree_content = rbuf + tree_off + 9;
  I64 tree_content_len = tree_record_len - 1; // minus the OBJ_TREE tag byte

  // Pass 1: new / modified / unchanged, driven by what's actually on
  // disk right now.
  CDirEntry *tmpde = FilesFind(find_mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 fsize;
    U8 *fbuf = FileRead(tmpde->full_name, &fsize);
    U8 tagged[512];
    tagged[0] = OBJ_BLOB;
    I64 i;
    for (i=0; i<fsize; i++) tagged[1+i] = fbuf[i];
    U8 file_hash[64];
    B2Hash512Any(tagged, fsize+1, file_hash);

    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;

    U8 tree_type;
    U8 tree_entry_hash[64];
    U64 tree_entity_id;
    Bool in_tree = TreeFindEntry(tree_content, tree_content_len,
                                  tmpde->full_name+name_start, name_len,
                                  &tree_type, tree_entry_hash, &tree_entity_id);
    if (!in_tree) {
      CommPrint(1, "STATUS_NEW ");
    } else {
      Bool same = TRUE;
      for (i=0; i<64; i++) if (file_hash[i] != tree_entry_hash[i]) same = FALSE;
      if (same) CommPrint(1, "STATUS_UNCHANGED ");
      else CommPrint(1, "STATUS_MODIFIED ");
    }
    for (j=name_start; tmpde->full_name[j]; j++) CommPrint(1, "%c", tmpde->full_name[j]);
    CommPrint(1, "\n");
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);

  // Pass 2: deleted - walk every tree entry, check it still exists on
  // disk. This is the only place hgit-core needs "everything the tree
  // says should exist," so it's done inline here rather than adding a
  // generic tree-iteration API to Tree.HC for a single caller.
  U32 tcount = GetU32LE(tree_content, 0);
  I64 tpos = 4;
  U32 te;
  for (te=0; te<tcount; te++) {
    U8 tname_len = tree_content[tpos]; tpos += 1;
    U8 *tname = tree_content + tpos; tpos += tname_len;
    tpos += 1; // skip type
    tpos += 64; // skip hash
    tpos += 8; // skip entity_id (ADR 0004)

    U8 check_path[256];
    I64 k = 0;
    while (dir_prefix[k]) { check_path[k] = dir_prefix[k]; k++; }
    I64 m;
    for (m=0; m<tname_len; m++) check_path[k+m] = tname[m];
    check_path[k+tname_len] = 0;

    I64 check_size;
    U8 *check_buf = FileRead(check_path, &check_size);
    if (check_buf == NULL) {
      CommPrint(1, "STATUS_DELETED ");
      for (m=0; m<tname_len; m++) CommPrint(1, "%c", tname[m]);
      CommPrint(1, "\n");
    }
  }
  CommPrint(1, "STATUS_END\n");
}
// History.HC — `hgit history`: walk the parent chain from HEAD,
// printing each commit's timestamp and message.
//
// First real consumer of Index.HC's lookup for something other than a
// single dereference (probe 12's tree-entry case) - here it's walked
// repeatedly, once per commit, back through the parent chain. Only
// single-parent chains are followed (CommitParentHash(content, 0)) -
// merge commits (parent_count > 1) aren't walked specially yet, since
// none have been created or tested (Commit.HC's own "not yet done").
//
// Verified (experiments/19-hgit-history/) against the real two-commit
// repository `hgit offer` built in the previous session/probe - not a
// fresh fixture, an actual persisted repo from prior work, which this
// probe read back correctly across the QEMU reboot boundary.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC, Head.HC.

U0 HgitHistory(U8 *repo_path)
{
  U8 head_hash[64];
  if (!CurrentHeadRead(repo_path, head_hash)) {
    CommPrint(1, "HISTORY_EMPTY\n");
    return;
  }

  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  U8 idx_hashes[64*64];
  I64 idx_offsets[64];
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  U8 cur_hash[64];
  I64 k;
  for (k=0; k<64; k++) cur_hash[k] = head_hash[k];
  Bool has_cur = TRUE;
  I64 shown = 0;

  while (has_cur) {
    I64 off_rel;
    Bool found = IndexLookup(idx_hashes, idx_offsets, idx_count, cur_hash, &off_rel);
    if (!found) { CommPrint(1, "HISTORY_ERR broken_chain\n"); return; }
    // IndexBuild's offsets are relative to the object section
    // (rbuf+16 was passed as its archive_buf), NOT the whole file -
    // must add the 16-byte header back to index into rbuf directly.
    // Same lesson as probe 12 (see failed-approaches.md) - got this
    // wrong again in a throwaway debug script while building this
    // very function, caught it, and this comment exists so it doesn't
    // happen a third time.
    I64 off = 16 + off_rel;
    U8 obj_type = rbuf[off+8];
    U8 *content = rbuf + off + 9;
    if (obj_type != OBJ_COMMIT) { CommPrint(1, "HISTORY_ERR not_a_commit type=%d\n", obj_type); return; }

    U8 pcount = CommitParentCount(content);
    U64 ts = CommitTimestamp(content);
    U32 mlen = CommitMessageLen(content);
    U8 *msg = CommitMessage(content);

    CommPrint(1, "commit ts=%d msg=", ts);
    for (k=0; k<mlen; k++) CommPrint(1, "%c", msg[k]);
    CommPrint(1, "\n");
    shown++;

    if (pcount > 0) {
      U8 *parent = CommitParentHash(content, 0);
      for (k=0; k<64; k++) cur_hash[k] = parent[k];
      has_cur = TRUE;
    } else {
      has_cur = FALSE;
    }
  }
  CommPrint(1, "HISTORY_END shown=%d\n", shown);
}
// Hex.HC — hex string <-> raw hash bytes conversion.
//
// Every hgit-core/hgit-cli function so far takes a hash as raw 64
// bytes (the same convention throughout, e.g. Commit.HC's
// CommitParentHash, Index.HC's IndexLookup). Nothing needed to convert
// to/from a human-typeable hex string until `hgit see <offering>`
// needed to accept one at the actual cmd line. Verified
// (experiments/25-hex-hash/): round-tripped a real commit hash through
// hex and back losslessly, and confirmed invalid hex is rejected
// rather than silently accepted as zero/garbage.

U8 HexDigit(U8 c)
{
  if (c>='0' && c<='9') return c-'0';
  if (c>='a' && c<='f') return c-'a'+10;
  if (c>='A' && c<='F') return c-'A'+10;
  return 0xFF; // sentinel for invalid - caller must check for this
}

// hex must be exactly 128 characters (no NUL check here - caller's
// job). Returns FALSE without touching hash_out fully if any character
// isn't a valid hex digit - don't trust hash_out on a FALSE return.
Bool HexToHash(U8 *hex, U8 *hash_out)
{
  I64 i;
  for (i=0; i<64; i++) {
    U8 hi = HexDigit(hex[i*2]);
    U8 lo = HexDigit(hex[i*2+1]);
    if (hi==0xFF || lo==0xFF) return FALSE;
    hash_out[i] = (hi<<4)|lo;
  }
  return TRUE;
}

// Writes 128 lowercase hex chars + NUL (129 bytes total) into hex_out.
U0 HashToHex(U8 *hash, U8 *hex_out)
{
  U8 *digits = "0123456789abcdef";
  I64 i;
  for (i=0; i<64; i++) {
    hex_out[i*2]   = digits[hash[i]>>4];
    hex_out[i*2+1] = digits[hash[i]&0xF];
  }
  hex_out[128] = 0;
}
// HistoryDoc.HC — `hgit historydoc`: the real DolDoc history view.
//
// Probe 46 (`experiments/46-doldoc-format/`) resolved the research
// question this depends on: `$..$` DolDoc commands are literal plain
// text, and a HolyC-written `.DD` file (via plain `FileWrite`) renders
// correctly when opened. This is that research put to use: walks the
// same parent chain `History.HC`'s `HgitHistory` already walks
// (reimplemented here rather than shared, since the two build very
// different output - plain `CommPrint` text vs. a `$..$`-formatted
// buffer), building a colored, real DolDoc document instead of plain
// text, then writes it with a normal `FileWrite` - no special API.
//
// Verified colors so far: `$FG,2$...$FG$` (green - used for the commit
// hash) and `$FG,4$...$FG$` (used for the timestamp) - the exact two
// color commands probe 46 confirmed render correctly from
// HolyC-generated output; `$CR$` for hard line breaks between commits.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC, Paths.HC (CurrentHeadRead), Hex.HC (HashToHex, for the
// hash shown per commit - not needed by plain HgitHistory, which never
// showed a hash at all).

U0 HgitHistoryDoc(U8 *repo_path, U8 *doc_path)
{
  U8 doc[8192];
  I64 dlen = 0;
  U8 *title = "$FG,5$hgit history$FG$$CR$$CR$";
  I64 ti;
  for (ti=0; title[ti]; ti++) doc[dlen++] = title[ti];

  U8 head_hash[64];
  if (!CurrentHeadRead(repo_path, head_hash)) {
    U8 *empty_msg = "(no offerings yet)$CR$";
    I64 ei;
    for (ei=0; empty_msg[ei]; ei++) doc[dlen++] = empty_msg[ei];
    FileWrite(doc_path, doc, dlen);
    return;
  }

  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  U8 idx_hashes[64*64];
  I64 idx_offsets[64];
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  U8 cur_hash[64];
  I64 k;
  for (k=0; k<64; k++) cur_hash[k] = head_hash[k];
  Bool has_cur = TRUE;

  while (has_cur) {
    I64 off_rel;
    Bool found = IndexLookup(idx_hashes, idx_offsets, idx_count, cur_hash, &off_rel);
    if (!found) break; // broken chain - stop, don't crash the doc write
    I64 off = 16 + off_rel; // same offset-relative-to-object-section
                             // gotcha as History.HC/See.HC - see those
                             // files' own comments, not repeated here.
    U8 obj_type = rbuf[off+8];
    U8 *content = rbuf + off + 9;
    if (obj_type != OBJ_COMMIT) break;

    U8 pcount = CommitParentCount(content);
    U64 ts = CommitTimestamp(content);
    U32 mlen = CommitMessageLen(content);
    U8 *msg = CommitMessage(content);

    U8 hex[129];
    HashToHex(cur_hash, hex);

    U8 *fg_hash = "$FG,2$";
    I64 fi;
    for (fi=0; fg_hash[fi]; fi++) doc[dlen++] = fg_hash[fi];
    // show a short prefix of the hash, not the full 128 hex chars -
    // matches how a real history view would want to display this
    // (full hash is still recoverable via `hgit see`).
    I64 hi;
    for (hi=0; hi<12; hi++) doc[dlen++] = hex[hi];
    U8 *fg_end = "$FG$ ";
    for (fi=0; fg_end[fi]; fi++) doc[dlen++] = fg_end[fi];

    U8 *fg_ts = "$FG,4$";
    for (fi=0; fg_ts[fi]; fi++) doc[dlen++] = fg_ts[fi];
    U8 ts_digits[24];
    I64 tlen = 0;
    if (ts == 0) { ts_digits[tlen++] = '0'; }
    U64 tsv = ts;
    U8 rev[24];
    I64 rlen = 0;
    while (tsv > 0) { rev[rlen++] = '0' + (tsv % 10); tsv /= 10; }
    for (fi=rlen-1; fi>=0; fi--) ts_digits[tlen++] = rev[fi];
    for (fi=0; fi<tlen; fi++) doc[dlen++] = ts_digits[fi];
    for (fi=0; fg_end[fi]; fi++) doc[dlen++] = fg_end[fi];

    for (k=0; k<mlen; k++) doc[dlen++] = msg[k];
    U8 *cr = "$CR$";
    for (fi=0; cr[fi]; fi++) doc[dlen++] = cr[fi];

    if (pcount > 0) {
      U8 *parent = CommitParentHash(content, 0);
      for (k=0; k<64; k++) cur_hash[k] = parent[k];
      has_cur = TRUE;
    } else {
      has_cur = FALSE;
    }
  }

  FileWrite(doc_path, doc, dlen);
}
// See.HC — `hgit see <offering>`: show one commit's full detail -
// message, timestamp, parent count, and its tree's entries.
//
// Takes the target commit as a raw 64-byte hash (same convention as
// every other hgit-core/hgit-cli function so far) rather than a hex
// string - hex parsing is a real, separate question for the eventual
// argv-driven entry point, not yet needed or built.
//
// Verified (experiments/22-hgit-see/) against the real two-commit
// repository from probes 18-21: shown HEAD (the "second" commit, 1
// parent, its tree's 2 entries), walked to and shown its parent (the
// root "first" commit, 0 parents), and confirmed a hash absent from the
// repo reports SEE_ERR cleanly rather than crashing or guessing.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC.
//
// Tree-entry parsing updated for ADR 0004's 8-byte entity ID field
// (experiments/49-entity-id/) - this file walks tree entries manually
// (not via Tree.HC's TreeFindEntry) so it needed its own offset fix.

U0 HgitSee(U8 *repo_path, U8 *target_hash)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "SEE_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "SEE_ERR bad_header\n"); return; }

  U8 idx_hashes[64*64];
  I64 idx_offsets[64];
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 off_rel;
  Bool found = IndexLookup(idx_hashes, idx_offsets, idx_count, target_hash, &off_rel);
  if (!found) { CommPrint(1, "SEE_ERR not_found\n"); return; }
  I64 off = 16 + off_rel; // Index offsets are relative to the object
                           // section (rbuf+16) - see probe 12/19/20's
                           // recurring lesson.
  U8 obj_type = rbuf[off+8];
  if (obj_type != OBJ_COMMIT) { CommPrint(1, "SEE_ERR not_a_commit type=%d\n", obj_type); return; }
  U8 *content = rbuf + off + 9;

  U8 pcount = CommitParentCount(content);
  U64 ts = CommitTimestamp(content);
  U32 mlen = CommitMessageLen(content);
  U8 *msg = CommitMessage(content);
  U8 *tree_hash = CommitTreeHash(content);

  I64 i;
  CommPrint(1, "SEE_COMMIT ts=%d parents=%d msg=", ts, pcount);
  for (i=0; i<mlen; i++) CommPrint(1, "%c", msg[i]);
  CommPrint(1, "\n");

  I64 tree_off_rel;
  Bool tree_found = IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &tree_off_rel);
  if (!tree_found) { CommPrint(1, "SEE_ERR tree_not_found\n"); return; }
  I64 tree_off = 16 + tree_off_rel;
  U64 tree_len = GetU64LE(rbuf, tree_off);
  U8 *tree_content = rbuf + tree_off + 9;

  U32 tcount = GetU32LE(tree_content, 0);
  I64 tpos = 4;
  U32 te;
  CommPrint(1, "SEE_TREE entries=%d\n", tcount);
  for (te=0; te<tcount; te++) {
    U8 nlen = tree_content[tpos]; tpos += 1;
    U8 *name = tree_content + tpos; tpos += nlen;
    U8 ttype = tree_content[tpos]; tpos += 1;
    tpos += 64;
    U64 entity_id = GetU64LE(tree_content, tpos); tpos += 8; // ADR 0004
    CommPrint(1, "  entry type=%d id=%d name=", ttype, entity_id);
    for (i=0; i<nlen; i++) CommPrint(1, "%c", name[i]);
    CommPrint(1, "\n");
  }
  CommPrint(1, "SEE_END\n");
}
// OpLog.HC — the tool-operation log, separate from project history
// (commits), per the product thesis: "Project history and tool-
// operation history are separate. Every modifying hgit command records
// an operation so ordinary recovery becomes: hgit undo / hgit redo /
// hgit operation history / hgit operation restore <operation>."
//
// Probe 44: this file's PUBLIC API (OpLogAppend/OpLogUndo/OpLogRedo/
// OpLogHistory/OpLogRestore) is now backed by `src/hgit-core/Meta.HC`'s
// operation-log slice internally, completing ADR 0003's real-command
// cutover started in probe 43 (which moved Paths.HC over the same
// way). Every function's SIGNATURE and observable behavior is
// unchanged - Offer.HC and Hgit.HC needed no changes at all. This
// retires the old `.oplog.<name>`/`.redolog.<name>` sidecar files that
// motivated ADR 0003 in the first place.
//
// All operations are scoped to whichever path is CURRENT right now
// (via Paths.HC's CurrentPathGet - reused, not reimplemented), same
// path-scoping this file already had since probe 36.
//
// Depends on Meta.HC (MetaOpLogAppend/MetaOpLogPopLast/MetaOpLogGet/
// MetaOpLogCount/MetaRedoLogAppend/MetaRedoLogPopLast/MetaRedoLogClear),
// Paths.HC (CurrentPathGet, CurrentHeadWrite, HGIT_MAX_PATH_NAME), and
// Hex.HC (HashToHex, for OpLogHistory's printable output only - kept
// out of Meta.HC itself, which shouldn't depend on hgit-cli).

// Logs a real operation (e.g. offer) for the current path. Also
// clears that path's redo log: doing new work after an undo
// invalidates whatever was undone, same as any other tool's undo/redo
// stack. Deliberately not done inside MetaOpLogAppend itself, since
// OpLogRedo (below) also calls it and must NOT clear the redo log as
// a side effect of that internal reuse.
U0 OpLogAppend(U8 *repo_path, U8 *prev_head, U8 *new_head, U64 timestamp)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  MetaOpLogAppend(repo_path, cur_name, prev_head, new_head, timestamp);
  MetaRedoLogClear(repo_path, cur_name);
}

// Restores HEAD to the most recently logged operation's prev_head,
// removes that entry from the undo log, and pushes it onto the redo
// log so OpLogRedo can replay it. Returns FALSE (no change made) if
// there's nothing to undo for the current path.
Bool OpLogUndo(U8 *repo_path)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  U8 prev_head[64], new_head[64];
  U64 ts;
  Bool found = MetaOpLogPopLast(repo_path, cur_name, prev_head, new_head, &ts);
  if (!found) return FALSE;
  CurrentHeadWrite(repo_path, prev_head);
  MetaRedoLogAppend(repo_path, cur_name, prev_head, new_head, ts);
  return TRUE;
}

// Re-applies the most recently undone operation for the current path:
// sets HEAD back to that entry's new_head, removes it from the redo
// log, and pushes it back onto the undo log. Returns FALSE if there's
// nothing to redo.
Bool OpLogRedo(U8 *repo_path)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  U8 prev_head[64], new_head[64];
  U64 ts;
  Bool found = MetaRedoLogPopLast(repo_path, cur_name, prev_head, new_head, &ts);
  if (!found) return FALSE;
  CurrentHeadWrite(repo_path, new_head);
  MetaOpLogAppend(repo_path, cur_name, prev_head, new_head, ts);
  return TRUE;
}

// Prints every logged operation for the current path (oldest first):
// index, timestamp, and the prev_head/new_head hashes in hex.
// Read-only - doesn't touch HEAD or either log.
U0 OpLogHistory(U8 *repo_path)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  I64 count = MetaOpLogCount(repo_path, cur_name);
  if (count == 0) {
    CommPrint(1, "OPLOG_EMPTY\n");
    return;
  }
  I64 i;
  for (i=0; i<count; i++) {
    U8 prev_head[64], new_head[64];
    U64 ts;
    MetaOpLogGet(repo_path, cur_name, i, prev_head, new_head, &ts);
    U8 prev_hex[129], new_hex[129];
    HashToHex(prev_head, prev_hex);
    HashToHex(new_head, new_hex);
    CommPrint(1, "OP %d ts=%d prev=%s new=%s\n", i, ts, prev_hex, new_hex);
  }
}

// Jumps the current path's HEAD directly to the `new_head` recorded
// by the operation at `index` (0-based, oldest first - same numbering
// OpLogHistory prints), regardless of how many steps away that is.
// Deliberately does not touch the undo/redo logs (see OpLog.HC's
// original design note, unchanged from probe 38): reconciling an
// arbitrary restore with undo/redo afterward is out of scope.
Bool OpLogRestore(U8 *repo_path, I64 index)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  U8 prev_head[64], new_head[64];
  U64 ts;
  Bool found = MetaOpLogGet(repo_path, cur_name, index, prev_head, new_head, &ts);
  if (!found) return FALSE;
  CurrentHeadWrite(repo_path, new_head);
  return TRUE;
}
// Portable.HC — whole-repo export/import.
//
// Probe 39 proved the OBJECT layer (`.hgs` bytes alone) is portable -
// but a copied `.hgs` file had no HEAD, no paths, no history, because
// those lived in N separate sidecar files keyed to the exact original
// repo path. Now that ADR 0003 is fully wired in (probe 44), a repo's
// ENTIRE state - object layer plus every tool-state concern (HEAD,
// path list, current-path, operation log, redo log) - lives in exactly
// TWO files: `<repo_path>` itself and `<repo_path>.m` (Meta.HC). So a
// full, WORKING copy - not just the object bytes - is just copying
// both files. This is a direct, concrete payoff of ADR 0003's design,
// not a new architectural idea.
//
// `hgit export <repo> <dest>` and `hgit import <src> <dest>` are the
// same underlying copy, named for the two directions of use.
//
// Depends on Meta.HC (MetaPath, to find the `.m` file alongside the
// object file).

U0 CopyFileIfExists(U8 *src_path, U8 *dest_path)
{
  I64 size;
  U8 *buf = FileRead(src_path, &size);
  if (buf == NULL) return;
  FileWrite(dest_path, buf, size);
}

// Copies a repo's full state (object layer + Meta.HC's combined
// metadata file) from src_repo_path to dest_repo_path. If src has no
// `.m` file yet (never touched paths/undo/redo), only the object file
// is copied - a plain object-layer copy, same as probe 39, still
// works fine on the far end (Meta.HC's own functions all default
// sensibly to "main"/empty when their `.m` file doesn't exist).
U0 HgitCopyRepo(U8 *src_repo_path, U8 *dest_repo_path)
{
  CopyFileIfExists(src_repo_path, dest_repo_path);
  U8 src_meta[256], dest_meta[256];
  MetaPath(src_repo_path, src_meta);
  MetaPath(dest_repo_path, dest_meta);
  CopyFileIfExists(src_meta, dest_meta);
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
// Tree.HC, Commit.HC (the whole hgit-core object layer), Head.HC,
// Index.HC, and OpLog.HC. Every offer now logs its own HEAD
// before/after transition via OpLogAppend before moving HEAD, so
// `hgit undo` (OpLogUndo) can revert it - wired in and verified in
// experiments/31-oplog-in-offer/ (probe 30 had only called OpLogAppend
// manually, alongside offer, not from within it).
//
// Per ADR 0004 (experiments/49-entity-id/): each tree entry now
// carries a stable entity ID. If there's a parent commit, its tree is
// looked up first so each currently-offered file's ID can be copied
// forward from the OLD entry of the same name (TreeFindEntry) -
// otherwise (new name, or root offering) a fresh ID is generated
// (Tree.HC's GenerateEntityId). Deliberately minimal: same name = same
// identity; an actual rename is NOT detected here (see ADR 0004's own
// "what this slice does not do").

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

  // Parent lookup happens BEFORE building the new tree, so each file's
  // entity ID can be carried forward from the parent's own tree.
  U8 parent_hash[64];
  Bool has_parent = CurrentHeadRead(repo_path, parent_hash);

  U8 old_idx_hashes[64*64];
  I64 old_idx_offsets[64];
  I64 old_idx_count = 0;
  U8 *old_tree_content = NULL;
  I64 old_tree_content_len = 0;
  if (has_parent) {
    IndexBuild(rbuf+16, rsize-16, old_idx_hashes, old_idx_offsets, &old_idx_count);
    I64 pc_off_rel;
    Bool pc_found = IndexLookup(old_idx_hashes, old_idx_offsets, old_idx_count,
                                 parent_hash, &pc_off_rel);
    if (pc_found) {
      I64 pc_off = 16 + pc_off_rel;
      U8 *pc_content = rbuf + pc_off + 9;
      U8 *old_tree_hash = CommitTreeHash(pc_content);
      I64 ot_off_rel;
      Bool ot_found = IndexLookup(old_idx_hashes, old_idx_offsets, old_idx_count,
                                   old_tree_hash, &ot_off_rel);
      if (ot_found) {
        I64 ot_off = 16 + ot_off_rel;
        U64 ot_record_len = GetU64LE(rbuf, ot_off);
        old_tree_content = rbuf + ot_off + 9;
        old_tree_content_len = ot_record_len - 1; // minus the OBJ_TREE tag byte
      }
    }
  }

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

    U64 entity_id;
    Bool found_old = FALSE;
    if (old_tree_content != NULL) {
      U8 old_type;
      U8 old_hash[64];
      found_old = TreeFindEntry(old_tree_content, old_tree_content_len,
                                 tmpde->full_name+name_start, name_len,
                                 &old_type, old_hash, &entity_id);
    }
    if (!found_old) entity_id = GenerateEntityId();

    TreeEncodeEntry(tree_content, &tlen, tmpde->full_name+name_start, name_len,
                     OBJ_BLOB, blob_hash, entity_id);
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

  // Commit content itself (has_parent/parent_hash already computed above).
  U8 commit_content[512];
  I64 clen = 0;
  CommitEncode(commit_content, &clen, tree_hash, parent_hash,
               has_parent, timestamp, message, message_len,
               REL_NONE, NULL);
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

  // Log this offer's HEAD transition before moving HEAD, so `undo` can
  // revert it. No-parent case logs an all-zero prev_head sentinel
  // (parent_hash is uninitialized stack garbage when has_parent is
  // FALSE - never read it in that case).
  U8 log_prev_head[64];
  if (has_parent) {
    for (i=0; i<64; i++) log_prev_head[i] = parent_hash[i];
  } else {
    for (i=0; i<64; i++) log_prev_head[i] = 0;
  }
  OpLogAppend(repo_path, log_prev_head, commit_hash, timestamp);

  CurrentHeadWrite(repo_path, commit_hash);
}
// Hgit.HC — the actual entry point. Resolves the open question from
// doc 01 ("how does an argv-taking hgit command fit a system whose cmd
// line is a live HolyC REPL") - the premise was wrong. TempleOS has NO
// space-separated shell-argument syntax at all (confirmed from primary
// source, Doc/CmdLineOverview.DD: every native "command" - Dir(...),
// Cd(...), Ed(...) - is a literal HolyC function call with normal
// parens/string-literal args, never bare unquoted tokens). So there is
// no argv/main() convention to fit into.
//
// hgit's entry point is one function, `Hgit`, taking a single string
// exactly the way every other native command takes its one string
// argument. It splits the first space-separated word as a command name
// and dispatches to the already-independently-verified `Hgit*()`
// functions (Init.HC, Status.HC, Offer.HC, History.HC, See.HC). Called
// at the cmd line exactly like any other TempleOS command:
//
//     Hgit("init C:/Home/MyRepo.hgs");
//     Hgit("init \"C:/Home/My Repo.hgs\"");   // quoted path, spaces OK
//     Hgit("status C:/Home/MyRepo.hgs C:/Home/MyFiles* C:/Home/");
//     Hgit("history C:/Home/MyRepo.hgs");
//
// Verified (experiments/23-hgit-dispatch/, experiments/24-hgit-dispatch-more/,
// experiments/26-hgit-see-dispatch/, experiments/27-hgit-offer-dispatch/):
// all five commands (init/status/history/see/offer) dispatch correctly
// against a real repository, and an unknown command reports cleanly.
// `offer`'s free-text message (spaces preserved, not truncated at the
// first space) round-tripped correctly through a real commit and back
// out via `see`.
//
// IMPORTANT HolyC quirk, confirmed by testing (see
// experiments/24-hgit-dispatch-more/): declaring a same-named local
// variable in two different `else if` branches of ONE function can
// throw "Duplicate member" at compile time - HolyC's local-variable
// scope for `if`/`else if` branches inside a single function does not
// appear to be block-scoped the way C's is. Every branch below uses a
// distinctly-named local for anything that isn't shared across
// branches (e.g. `hist_repo_path`, not a second `repo_path`) - don't
// "clean this up" by reusing a name from another branch.
//
// `offer`'s free-text message is everything after its first two
// tokens (repo path, find mask), taken verbatim via StrLen - not
// further split on spaces. Its timestamp is `cnts.jiffies` (confirmed
// real, `Kernel/KTask.HC` uses it directly as a plain comparable/
// addable number) - a monotonic jiffy count, not wall-clock time; see
// Commit.HC's own note that the timestamp's real-world meaning is
// still undecided.
//
// IMPORTANT: every branch here is compiled as part of ONE function
// body, so HolyC must resolve every symbol any branch references at
// COMPILE time, regardless of which branch runs. Concretely: testing
// ANY single command through this file requires including ALL of
// Init.HC, Status.HC (+ WorkDir.HC), History.HC, See.HC (+ Hex.HC),
// and Offer.HC - not just the one command being tested. Forgetting one
// throws a real compile error naming the missing function (e.g.
// "Compiler Parse Error at 'HgitInit'") - this happened three times
// while building this file (experiments/26, 27) and was first
// misdiagnosed as a session-state issue before the actual pattern
// (missing dependency, not session weirdness) was confirmed. See
// failed-approaches.md's corrected entry.
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC, Object.HC,
// Tree.HC, Commit.HC, Index.HC, Init.HC, Head.HC, WorkDir.HC,
// Status.HC, History.HC, See.HC, Hex.HC, Offer.HC.

// Extracts the next token from `s` starting at `pos`. A token wrapped
// in double quotes (`"like this"`) is read up to the matching closing
// quote - allowing spaces inside - with the quotes themselves stripped
// from `out`; otherwise reads up to the next space, as before.
// Verified (experiments/29-hgit-quoting/): a real file created at a
// space-containing path via a quoted argument round-tripped correctly
// through FileWrite/FileRead; plain unquoted tokens are unaffected
// (confirmed same output/position as before this was added).
I64 ExtractToken(U8 *s, I64 pos, U8 *out, I64 out_max)
{
  while (s[pos]==' ') pos++;
  I64 i=0;
  if (s[pos]=='"') {
    pos++;
    while (s[pos] && s[pos]!='"' && i<out_max-1) { out[i]=s[pos]; i++; pos++; }
    if (s[pos]=='"') pos++;
  } else {
    while (s[pos] && s[pos]!=' ' && i<out_max-1) { out[i]=s[pos]; i++; pos++; }
  }
  out[i]=0;
  while (s[pos]==' ') pos++;
  return pos;
}

// Parses a non-negative decimal integer from a NUL-terminated string
// (digits only - no sign, no whitespace skipping beyond what
// ExtractToken already stripped). Just enough for a small index like
// `hgit operation restore <op>`'s <op> argument; not a general atoi.
I64 ParseI64(U8 *s)
{
  I64 v = 0;
  I64 i = 0;
  while (s[i] >= '0' && s[i] <= '9') {
    v = v*10 + (s[i]-'0');
    i++;
  }
  return v;
}

U0 Hgit(U8 *cmdline)
{
  I64 i = 0;
  while (cmdline[i] && cmdline[i] != ' ') i++;
  U8 cmd[32];
  I64 j;
  for (j=0; j<i && j<31; j++) cmd[j] = cmdline[j];
  cmd[j] = 0;

  U8 *rest = cmdline + i;
  while (*rest == ' ') rest++;

  if (StrCmp(cmd, "init") == 0) {
    U8 init_path[256];
    ExtractToken(rest, 0, init_path, 256);
    Bool ok = HgitInit(init_path);
    if (ok) CommPrint(1, "DISPATCH_OK init %s\n", init_path);
    else CommPrint(1, "DISPATCH_ERR init_failed %s\n", init_path);
  } else if (StrCmp(cmd, "status") == 0) {
    U8 repo_path[256], find_mask[256], dir_prefix[256];
    I64 p = 0;
    p = ExtractToken(rest, p, repo_path, 256);
    p = ExtractToken(rest, p, find_mask, 256);
    p = ExtractToken(rest, p, dir_prefix, 256);
    HgitStatus(repo_path, find_mask, dir_prefix);
  } else if (StrCmp(cmd, "history") == 0) {
    U8 hist_repo_path[256];
    ExtractToken(rest, 0, hist_repo_path, 256);
    HgitHistory(hist_repo_path);
  } else if (StrCmp(cmd, "see") == 0) {
    U8 see_repo_path[256], see_hex[129];
    I64 see_p = 0;
    see_p = ExtractToken(rest, see_p, see_repo_path, 256);
    see_p = ExtractToken(rest, see_p, see_hex, 129);
    U8 see_hash[64];
    Bool see_ok = HexToHash(see_hex, see_hash);
    if (!see_ok) { CommPrint(1, "DISPATCH_ERR bad_hash %s\n", see_hex); return; }
    HgitSee(see_repo_path, see_hash);
  } else if (StrCmp(cmd, "offer") == 0) {
    U8 offer_repo_path[256], offer_find_mask[256];
    I64 offer_p = 0;
    offer_p = ExtractToken(rest, offer_p, offer_repo_path, 256);
    offer_p = ExtractToken(rest, offer_p, offer_find_mask, 256);
    U8 *offer_message = rest + offer_p;
    I64 offer_mlen = StrLen(offer_message);
    U64 offer_ts = cnts.jiffies;
    HgitOffer(offer_repo_path, offer_find_mask, offer_message, offer_mlen, offer_ts);
    CommPrint(1, "DISPATCH_OK offer\n");
  } else if (StrCmp(cmd, "undo") == 0) {
    U8 undo_repo_path[256];
    ExtractToken(rest, 0, undo_repo_path, 256);
    Bool undo_ok = OpLogUndo(undo_repo_path);
    if (undo_ok) CommPrint(1, "DISPATCH_OK undo\n");
    else CommPrint(1, "DISPATCH_ERR nothing_to_undo\n");
  } else if (StrCmp(cmd, "redo") == 0) {
    U8 redo_repo_path[256];
    ExtractToken(rest, 0, redo_repo_path, 256);
    Bool redo_ok = OpLogRedo(redo_repo_path);
    if (redo_ok) CommPrint(1, "DISPATCH_OK redo\n");
    else CommPrint(1, "DISPATCH_ERR nothing_to_redo\n");
  } else if (StrCmp(cmd, "operation") == 0) {
    // Two-word command ("operation history ...") - `cmd` above only
    // captured "operation", so pull the sub-command as the next token
    // of `rest` before treating whatever follows as the sub-command's
    // own arguments.
    U8 op_sub[32];
    I64 op_p = ExtractToken(rest, 0, op_sub, 32);
    if (StrCmp(op_sub, "history") == 0) {
      U8 op_hist_repo_path[256];
      ExtractToken(rest, op_p, op_hist_repo_path, 256);
      OpLogHistory(op_hist_repo_path);
      CommPrint(1, "DISPATCH_OK operation_history\n");
    } else if (StrCmp(op_sub, "restore") == 0) {
      U8 op_rest_repo_path[256], op_rest_idx_str[32];
      I64 op_rest_p = ExtractToken(rest, op_p, op_rest_repo_path, 256);
      ExtractToken(rest, op_rest_p, op_rest_idx_str, 32);
      I64 op_rest_idx = ParseI64(op_rest_idx_str);
      Bool op_rest_ok = OpLogRestore(op_rest_repo_path, op_rest_idx);
      if (op_rest_ok) CommPrint(1, "DISPATCH_OK operation_restore %d\n", op_rest_idx);
      else CommPrint(1, "DISPATCH_ERR operation_restore_failed %d\n", op_rest_idx);
    } else {
      CommPrint(1, "DISPATCH_ERR unknown_operation_subcommand %s\n", op_sub);
    }
  } else if (StrCmp(cmd, "path") == 0) {
    U8 path_sub[32];
    I64 path_p = ExtractToken(rest, 0, path_sub, 32);
    if (StrCmp(path_sub, "list") == 0) {
      U8 path_list_repo[256];
      ExtractToken(rest, path_p, path_list_repo, 256);
      PathListPrint(path_list_repo);
      CommPrint(1, "DISPATCH_OK path_list\n");
    } else if (StrCmp(path_sub, "new") == 0) {
      U8 path_new_repo[256], path_new_name[HGIT_MAX_PATH_NAME];
      I64 path_new_p = ExtractToken(rest, path_p, path_new_repo, 256);
      ExtractToken(rest, path_new_p, path_new_name, HGIT_MAX_PATH_NAME);
      Bool path_new_ok = PathNew(path_new_repo, path_new_name);
      if (path_new_ok) CommPrint(1, "DISPATCH_OK path_new %s\n", path_new_name);
      else CommPrint(1, "DISPATCH_ERR path_new_failed %s\n", path_new_name);
    } else if (StrCmp(path_sub, "go") == 0) {
      U8 path_go_repo[256], path_go_name[HGIT_MAX_PATH_NAME];
      I64 path_go_p = ExtractToken(rest, path_p, path_go_repo, 256);
      ExtractToken(rest, path_go_p, path_go_name, HGIT_MAX_PATH_NAME);
      Bool path_go_ok = PathGo(path_go_repo, path_go_name);
      if (path_go_ok) CommPrint(1, "DISPATCH_OK path_go %s\n", path_go_name);
      else CommPrint(1, "DISPATCH_ERR path_go_failed %s\n", path_go_name);
    } else if (StrCmp(path_sub, "close") == 0) {
      U8 path_close_repo[256], path_close_name[HGIT_MAX_PATH_NAME];
      I64 path_close_p = ExtractToken(rest, path_p, path_close_repo, 256);
      ExtractToken(rest, path_close_p, path_close_name, HGIT_MAX_PATH_NAME);
      Bool path_close_ok = PathClose(path_close_repo, path_close_name);
      if (path_close_ok) CommPrint(1, "DISPATCH_OK path_close %s\n", path_close_name);
      else CommPrint(1, "DISPATCH_ERR path_close_failed %s\n", path_close_name);
    } else {
      CommPrint(1, "DISPATCH_ERR unknown_path_subcommand %s\n", path_sub);
    }
  } else if (StrCmp(cmd, "historydoc") == 0) {
    U8 hdoc_repo[256], hdoc_dest[256];
    I64 hdoc_p = ExtractToken(rest, 0, hdoc_repo, 256);
    ExtractToken(rest, hdoc_p, hdoc_dest, 256);
    HgitHistoryDoc(hdoc_repo, hdoc_dest);
    CommPrint(1, "DISPATCH_OK historydoc\n");
  } else if (StrCmp(cmd, "export") == 0) {
    U8 export_src[256], export_dest[256];
    I64 export_p = ExtractToken(rest, 0, export_src, 256);
    ExtractToken(rest, export_p, export_dest, 256);
    HgitCopyRepo(export_src, export_dest);
    CommPrint(1, "DISPATCH_OK export\n");
  } else if (StrCmp(cmd, "import") == 0) {
    U8 import_src[256], import_dest[256];
    I64 import_p = ExtractToken(rest, 0, import_src, 256);
    ExtractToken(rest, import_p, import_dest, 256);
    HgitCopyRepo(import_src, import_dest);
    CommPrint(1, "DISPATCH_OK import\n");
  } else {
    CommPrint(1, "DISPATCH_ERR unknown_command %s\n", cmd);
  }
}
