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
// cap. This function's own scratch buffer used to be a fixed
// `tagged[4096]` stack array (dlen+1 <= 4096) - a real, shared
// per-object-content ceiling every caller (Offer.HC's own blob/tree
// content, Commit.HC's commit encoding) inherited silently. Probe 105
// (experiments/105-objectput-dynamic-tag/) found it's the actual root
// cause behind `Offer.HC`'s own separate `fsize+1 > 512` file-size
// skip (that guard exists BELOW this one and would still trip first
// today - see that probe's own "what this does not do" - but this is
// the real, shared, lower-level limit any fix at that layer would
// still be blocked by). `MAlloc`'d at exactly `dlen+1`, freed after
// the one `HgsPut` call that needs it - same "no guessed cap" pattern
// ADR 0007 already established for `Offer.HC`'s own `archive` buffer.
// Verified up to a real 10,000-byte object round-tripping correctly
// through `ArchiveVerify` (`experiments/105-objectput-dynamic-tag/`),
// well past the old 4095-byte ceiling.
U0 ObjectPut(U8 *archive_buf, I64 *len, U8 type, U8 *data, I64 dlen)
{
  U8 *tagged = MAlloc(dlen+1);
  I64 i;
  tagged[0] = type;
  for (i=0; i<dlen; i++) tagged[1+i] = data[i];
  HgsPut(archive_buf, len, tagged, dlen+1);
  Free(tagged);
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

// ADR 0009 (experiments/70-rename-detection/): finds the FIRST entry
// whose own child hash matches `target_hash` (64 bytes) - the
// content-addressed half of exact-content rename detection (the
// name-based half is `TreeFindEntry` above). Returns its entity ID via
// *entity_id_out. Returns FALSE if no entry has that hash. Same linear
// scan, same "first match wins" simplification as every by-name/
// by-hash lookup in this project so far - if multiple old entries
// share the same content hash (legitimately duplicate content under
// different names), this returns whichever one the scan reaches
// first, not necessarily "the" renamed one - documented in ADR 0009
// as a known limitation, not a hidden bug.
Bool TreeFindEntryByHash(U8 *tree_buf, I64 tree_len, U8 *target_hash, U64 *entity_id_out)
{
  U32 count = GetU32LE(tree_buf, 0);
  I64 pos = 4;
  U32 e;
  for (e=0; e<count; e++) {
    U8 this_name_len = tree_buf[pos]; pos += 1;
    U8 *this_hash = tree_buf + pos + this_name_len + 1;
    U64 this_entity_id = GetU64LE(tree_buf, pos+this_name_len+1+64);
    Bool same = TRUE;
    I64 hi;
    for (hi=0; hi<64; hi++) if (this_hash[hi] != target_hash[hi]) same = FALSE;
    if (same) {
      *entity_id_out = this_entity_id;
      return TRUE;
    }
    pos += this_name_len + 1 + 64 + 8;
  }
  return FALSE;
}
// Commit.HC — commit object content: a tree reference, zero or more
// parent references, a timestamp, a message, and (per ADR 0005/0006)
// an optional typed relation to an earlier commit, optionally scoped
// to a specific tracked entity. This is what goes in the `data`/`dlen`
// passed to ObjectPut with type=OBJ_COMMIT - the content design ADR
// 0001/FORMAT.md deferred alongside tree content. Verified end-to-end
// (root commit with 0 parents, child commit with 1 parent referencing
// the root, both referencing the same tree) in
// experiments/11-commit-object/; the relation fields verified in
// experiments/50-relation-vocabulary/; entity-scoping in
// experiments/53-entity-scoped-relations/.
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
//   if relation_tag != 0:
//     64 bytes relation_target_hash (the prior commit this relation
//               names - not necessarily the parent; a correction can
//               name a commit further back)
//     U64      relation_entity_id (0 = not entity-scoped, the relation
//               applies to the whole commit - ADR 0005's original
//               behavior; any other value names a specific entity ID
//               from ADR 0004's tree entries. 0 as "unscoped" is a
//               practical sentinel, not formally collision-proof - a
//               real GenerateEntityId() landing on exactly 0 is
//               vanishingly unlikely, same honest caveat OpLog.HC's
//               own all-zero prev_head sentinel already carries.)
//
// The relation fields are placed AFTER the message deliberately: every
// accessor that reads UP TO the message (CommitTimestamp/
// CommitMessageLen/CommitMessage) keeps its existing offset math
// unchanged. Anything reading the relation fields recomputes from
// CommitMessageLen instead of assuming a fixed offset.
//
// Depends on Canon.HC (PutU64LE/GetU64LE/PutU32LE/GetU32LE).

#define REL_NONE      0
#define REL_CONTINUES 1
#define REL_CORRECTS  2
#define REL_REVERTS   3
#define REL_RECONCILES 4

// `relation_tag`/`relation_target` may be REL_NONE/NULL for an
// ordinary commit with no explicit relation (the common case - costs
// exactly one byte). `relation_entity_id` is ignored when
// relation_tag is REL_NONE; pass 0 for "not entity-scoped" otherwise.
U0 CommitEncode(U8 *buf, I64 *len, U8 *tree_hash, U8 *parent_hashes,
                U8 parent_count, U64 timestamp, U8 *message, I64 message_len,
                U8 relation_tag, U8 *relation_target, U64 relation_entity_id)
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
    PutU64LE(buf, *len, relation_entity_id); *len += 8;
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

// Only valid to call if CommitRelationTag(buf) != REL_NONE - returns
// the entity ID this relation is scoped to (0 = not entity-scoped,
// applies to the whole commit - see this file's own header comment on
// why 0 is a safe sentinel).
U64 CommitRelationEntityId(U8 *buf)
{
  return GetU64LE(buf, CommitRelationOffset(buf) + 1 + 64);
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
// (not recomputed) plus its start offset. IndexLookup is a linear
// scan over the result - every real command still uses this path.
// A real O(1)-expected hash table (IndexBuildHashTable/
// IndexLookupHashTable, probe 104) exists below but isn't wired into
// any call site yet - no evidence at hgit's current real scale (low
// hundreds of objects per repo) that the linear scan is a practical
// bottleneck, same "verify standalone before adopting" stance ADR
// 0008 took for Fossil.HC.
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

// Same scan as IndexLookup, but returns the array position (0..count-1)
// instead of the byte offset - for a caller (Check.HC's dangling-object
// walk, experiments/72-check-dangling-objects/) that needs to mark a
// per-object "visited" flag in a parallel array indexed the same way
// IndexBuild filled index_hashes/index_offsets, not the raw byte offset
// IndexLookup returns.
Bool IndexLookupPos(U8 *index_hashes, I64 count, U8 *target_hash, I64 *pos_out)
{
  I64 i, j;
  for (i=0; i<count; i++) {
    Bool same = TRUE;
    for (j=0; j<64; j++) if (index_hashes[i*64+j] != target_hash[j]) same = FALSE;
    if (same) { *pos_out = i; return TRUE; }
  }
  return FALSE;
}

// A real hash table, per doc 06's own long-standing "Not yet done"
// item ("a real hash table for the index"). NOT yet wired into any
// call site (Offer.HC/History.HC/Status.HC/See.HC/ReconcileDoc.HC's
// own six IndexLookup callers all still use the linear scan above) -
// same "build and verify standalone before adopting" pattern this
// project already used for Fossil.HC (ADR 0008): no real evidence yet
// that hgit's current real scale (low hundreds of objects per repo,
// per ADR 0013's own note) makes the linear scan a practical
// bottleneck. Open addressing with linear probing, hashed on the
// first 8 bytes of the (already near-uniform, BLAKE2b-derived) stored
// hash - no need for a stronger mix, since collisions just cost one
// extra probe step either way.
//
// Caller picks table_size (IndexHashTableSize below suggests one) and
// MAllocs `table` itself - this file doesn't own that memory, matching
// every other dynamic buffer in this codebase since ADR 0007.
I64 IndexHashTableSize(I64 count)
{
  // Odd and comfortably larger than count halves real-world clustering
  // for open addressing without needing count to be prime.
  return count*2 + 1;
}

U0 IndexBuildHashTable(U8 *index_hashes, I64 count, I64 *table, I64 table_size)
{
  I64 i, slot;
  for (i=0; i<table_size; i++) table[i] = -1;
  for (i=0; i<count; i++) {
    U64 h = GetU64LE(index_hashes + i*64, 0);
    slot = h % table_size;
    while (table[slot] != -1) slot = (slot+1) % table_size;
    table[slot] = i;
  }
}

// Same contract as IndexLookup (byte offset out), but O(1) expected
// instead of O(count) - reads index_offsets[table[slot]] once a
// matching stored hash is confirmed, same as the linear version does.
Bool IndexLookupHashTable(U8 *index_hashes, I64 *index_offsets, I64 *table,
                           I64 table_size, U8 *target_hash, I64 *offset_out)
{
  U64 h = GetU64LE(target_hash, 0);
  I64 slot = h % table_size;
  I64 tries = 0, idx, j;
  Bool same;
  while (table[slot] != -1 && tries < table_size) {
    idx = table[slot];
    same = TRUE;
    for (j=0; j<64; j++) if (index_hashes[idx*64+j] != target_hash[j]) same = FALSE;
    if (same) { *offset_out = index_offsets[idx]; return TRUE; }
    slot = (slot+1) % table_size;
    tries++;
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

// Real bug found and fixed (experiments/66-meta-dynamic-buffer/): every
// write function below used to rebuild the whole metadata file into a
// fixed `U8 new_buf[16384]` stack buffer before writing it back - the
// exact same class of bug ADR 0007 fixed in Offer.HC's `archive`, but
// worse here: it did NOT crash. A real 150-offer stress test grew this
// file past 16384 bytes (~144 bytes/offer - one HEAD record replace
// plus one oplog append) with zero error or crash, and silently lost
// data instead: only 115 of 150 real operation-log entries survived,
// and HEAD silently stopped advancing partway through, both without
// any error signal at all. `new_buf` is now `MAlloc`'d from the
// existing file's real size (already known from `FileRead`) plus this
// headroom for the one new record being written, freed on every exit
// path. A repo that behaves this way (writes silently stop taking
// effect, no error) is a much worse failure mode than probes 55/60/61's
// own crashes - a crash is at least visible.
#define META_BUF_HEADROOM 1024

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

  U8 *new_buf = MAlloc(total_old + META_BUF_HEADROOM);
  I64 new_len;
  MetaSpliceOut(buf, total_old, name, META_TAG_HEAD, new_buf, &new_len);
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_HEAD, hash, 64);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
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

  U8 *new_buf = MAlloc(total_old + META_BUF_HEADROOM);
  I64 new_len = 0;
  I64 i;
  for (i=0; i<total_old; i++) new_buf[i] = buf[i];
  new_len = total_old;
  U8 no_payload[1];
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_PATH_DECLARED, no_payload, 0);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
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
  U8 *new_buf = MAlloc(size + META_BUF_HEADROOM);
  I64 new_len;
  MetaSpliceOut(buf, size, name, META_TAG_PATH_DECLARED, new_buf, &new_len);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
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

// Real-count variant of the same scan MetaPathList does, for a caller
// (Check.HC's dangling-object walk, experiments/72-check-dangling-objects/)
// that needs to size a buffer first instead of just printing. Counts
// META_TAG_PATH_DECLARED records only - "main" is always implicit, not
// counted here (same convention MetaPathList's own hardcoded first
// line uses).
I64 MetaPathCount(U8 *repo_path)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return 0;
  I64 pos = 0, n = 0;
  while (pos < size) {
    U8 name_len = buf[pos]; pos += 1;
    pos += name_len;
    U8 rec_tag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    pos += payload_len;
    if (rec_tag == META_TAG_PATH_DECLARED) n++;
  }
  return n;
}

// Fills `out_names` (caller-provided, one META_MAX_PATH_NAME-byte slot
// per entry, sized from MetaPathCount(repo_path)+1) with every path
// name - "main" first, then each declared path, same order
// MetaPathList prints them in. Returns the real count via *out_count
// (always MetaPathCount(repo_path)+1, but computed directly here
// rather than trusting the caller's own earlier count stayed correct).
U0 MetaPathListInto(U8 *repo_path, U8 *out_names, I64 *out_count)
{
  I64 n = 0;
  out_names[0]='m'; out_names[1]='a'; out_names[2]='i'; out_names[3]='n';
  out_names[4]=0;
  n++;
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf != NULL) {
    I64 pos = 0;
    while (pos < size) {
      U8 name_len = buf[pos]; pos += 1;
      U8 *rec_name = buf + pos; pos += name_len;
      U8 rec_tag = buf[pos]; pos += 1;
      U8 payload_len = buf[pos]; pos += 1;
      pos += payload_len;
      if (rec_tag == META_TAG_PATH_DECLARED) {
        U8 *slot = out_names + n*META_MAX_PATH_NAME;
        I64 ni;
        for (ni=0; ni<name_len; ni++) slot[ni] = rec_name[ni];
        slot[name_len] = 0;
        n++;
      }
    }
  }
  *out_count = n;
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

  U8 *new_buf = MAlloc(total_old + META_BUF_HEADROOM);
  I64 new_len;
  MetaSpliceOut(buf, total_old, "", META_TAG_CURRENT, new_buf, &new_len);
  MetaAppendRecord(new_buf, &new_len, "", META_TAG_CURRENT, name, StrLen(name));
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
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

  U8 *new_buf = MAlloc(total_old + META_BUF_HEADROOM);
  I64 new_len = 0;
  for (bi=0; bi<total_old; bi++) new_buf[bi] = buf[bi];
  new_len = total_old;
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_OPLOG, payload, 136);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
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

  U8 *new_buf = MAlloc(size + META_BUF_HEADROOM);
  I64 new_len;
  U8 payload[136];
  I64 payload_len;
  Bool found = MetaSpliceOutLast(buf, size, name, META_TAG_OPLOG, new_buf, &new_len, payload, &payload_len);
  if (!found) { Free(new_buf); return FALSE; }

  *timestamp_out = GetU64LE(payload, 0);
  I64 bi;
  for (bi=0; bi<64; bi++) prev_head_out[bi] = payload[8+bi];
  for (bi=0; bi<64; bi++) new_head_out[bi] = payload[72+bi];

  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
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

  U8 *new_buf = MAlloc(total_old + META_BUF_HEADROOM);
  I64 new_len = 0;
  for (bi=0; bi<total_old; bi++) new_buf[bi] = buf[bi];
  new_len = total_old;
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_REDOLOG, payload, 136);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
}

Bool MetaRedoLogPopLast(U8 *repo_path, U8 *name, U8 *prev_head_out, U8 *new_head_out, U64 *timestamp_out)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return FALSE;

  U8 *new_buf = MAlloc(size + META_BUF_HEADROOM);
  I64 new_len;
  U8 payload[136];
  I64 payload_len;
  Bool found = MetaSpliceOutLast(buf, size, name, META_TAG_REDOLOG, new_buf, &new_len, payload, &payload_len);
  if (!found) { Free(new_buf); return FALSE; }

  *timestamp_out = GetU64LE(payload, 0);
  I64 bi;
  for (bi=0; bi<64; bi++) prev_head_out[bi] = payload[8+bi];
  for (bi=0; bi<64; bi++) new_head_out[bi] = payload[72+bi];

  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
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
  U8 *new_buf = MAlloc(size + META_BUF_HEADROOM);
  I64 new_len;
  MetaSpliceOut(buf, size, name, META_TAG_REDOLOG, new_buf, &new_len);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
}
// Fossil.HC — a minimal, byte-exact prototype of Fossil's delta
// format (docs/research/04-vcs-comparison.md), per that doc's own
// recommendation: "prototype Fossil's delta format specifically
// before inventing a new one."
//
// Every byte-level detail here is taken from Fossil's own real source
// (`src/delta.c`, via fossil-scm.org's own doc/source browser), not
// from a paraphrased summary - two earlier web summaries disagreed
// with each other on the alphabet's exact character order and the
// digit-write order, so the actual `putInt` C source was fetched
// directly to settle it. Confirmed:
//   - Alphabet (64 chars): "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~"
//     (underscore right after 'Z', before lowercase - NOT after 'z'
//     as one earlier summary claimed).
//   - Integers are variable-width base-64: 6 bits/char, MOST
//     significant 6-bit group written FIRST (standard positional
//     numeral order, same as decimal) - one earlier summary claimed
//     least-significant-first, which was wrong.
//   - Checksum: the payload treated as 32-bit big-endian words,
//     summed with natural U32 (mod 2^32) wraparound; 1-3 trailing
//     bytes are treated as if zero-padded at the low end (e.g. one
//     trailing byte contributes `byte<<24`).
//
// A real, previously-undocumented HolyC quirk found and fixed while
// verifying this (experiments/68-fossil-delta-format/), distinct from
// (and easy to confuse with) Canon.HC's own documented U32-return-
// value quirk: postfix-casting a raw byte read directly to `(I64)`
// produces GARBAGE - not the zero-extended byte value - while casting
// the exact same read to `(U64)` works correctly, even when the
// result is then used in an I64 context. Confirmed by direct,
// systematic isolation (experiments/68-fossil-delta-format/README.md
// has the full bisection): `buf[i](I64)` alone, assigned to a fresh
// I64 local, printed a huge garbage number; `buf[i](U64)` in the
// exact same position printed the correct byte value every time.
// Canon.HC's own working code (`GetU32LE`) already avoided this by
// convention - it only ever casts to `(U64)`, never `(I64)` - but
// its own comment doesn't call this out as the reason, so this file
// re-derives and documents it explicitly. Standing rule adopted here:
// cast a raw byte/array read to `(U64)`, never `(I64)`, even if the
// result will immediately be used as I64 - the resulting U64 value
// composes safely into I64 arithmetic/comparisons once it's clean.
//
// Depends on nothing but kernel string ops - self-contained.

// Encodes `v` as a variable-width base-64 integer, appending to
// buf/*len. Matches Fossil's own putInt() exactly: 0 is the single
// digit '0'; otherwise the most-significant 6-bit group is written
// first.
U0 FossilPutInt(I64 v, U8 *buf, I64 *len)
{
  U8 *digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~";
  if (v == 0) { buf[(*len)++] = '0'; return; }
  U8 tmp[8];
  I64 tcount = 0;
  while (v > 0) {
    tmp[tcount++] = digits[v & 0x3F];
    v >>= 6;
  }
  I64 ti;
  for (ti=tcount-1; ti>=0; ti--) buf[(*len)++] = tmp[ti];
}

// Returns the 0-63 alphabet index of `c`, or -1 if `c` isn't one of
// the 64 digit characters (i.e. it's a delimiter - '\n'/'@'/','/':'/
// ';' - the caller's cue to stop reading digits).
I64 FossilDigitValue(U8 c)
{
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'A' && c <= 'Z') return c - 'A' + 10;
  if (c == '_') return 36;
  if (c >= 'a' && c <= 'z') return c - 'a' + 37;
  if (c == '~') return 63;
  return -1;
}

// Reads a base-64 integer starting at buf[pos], stopping at the first
// non-digit character. Writes the decoded value to *value_out and
// returns the number of digit characters consumed (so the caller can
// advance pos itself and then handle the delimiter). `buf[pos+n]` is
// a plain U8 passed straight to FossilDigitValue (no cast needed - the
// function parameter is U8), so this function isn't itself exposed to
// the (I64)-cast-on-a-byte-read quirk described in the file header.
I64 FossilGetInt(U8 *buf, I64 pos, I64 *value_out)
{
  I64 v = 0;
  I64 n = 0;
  while (TRUE) {
    I64 d = FossilDigitValue(buf[pos+n]);
    if (d < 0) break;
    v = (v << 6) | d;
    n++;
  }
  *value_out = v;
  return n;
}

// Fossil's own checksum: treat `data` (len bytes) as 32-bit
// big-endian words and sum them with natural U32 (mod 2^32)
// wraparound; 1-3 trailing bytes are zero-padded at the low end
// (matches delta.c's own trailing-byte handling, confirmed from
// source rather than assumed).
//
// ROOT CAUSE FOUND AND FIXED (probe 80, experiments/80-fossil-checksum-root-cause/,
// closing ADR 0008's long-open caller-shape-sensitivity mystery): a
// raw byte cast to `(U64)` does NOT reliably zero-extend to a clean
// 64-bit value once the result is shifted left and OR'd/summed with
// other similarly-cast values in the same expression - stray garbage
// in the upper bits (left over from whatever previously occupied that
// register/stack slot, which is why this varied by caller shape)
// leaks into the final sum. A single-byte print (the original quirk
// verification, probe 68) never exposed this, because one clean byte
// value printed in isolation looks correct even with garbage above
// bit 7 - it only corrupts a *composed* multi-byte expression like
// this one. Fix: explicitly mask each cast byte with `& 0xFF` before
// shifting - verified against an independently-computed ground-truth
// checksum (Python, byte-for-byte) for a real 28-byte string: every
// per-word value and the final sum now match exactly, where every
// previous version (masked or not at the trailer-comparison level,
// heap or stack buffers, any caller shape) had produced a different
// wrong value.
U32 FossilChecksum(U8 *data, I64 len)
{
  U64 sum = 0;
  I64 pos = 0;
  while (pos + 4 <= len) {
    U64 word = ((data[pos](U64) & 0xFF) << 24) | ((data[pos+1](U64) & 0xFF) << 16) |
               ((data[pos+2](U64) & 0xFF) << 8) | (data[pos+3](U64) & 0xFF);
    sum += word;
    pos += 4;
  }
  I64 remaining = len - pos;
  if (remaining > 0) {
    U64 tail_word = 0;
    if (remaining >= 1) tail_word |= (data[pos](U64) & 0xFF) << 24;
    if (remaining >= 2) tail_word |= (data[pos+1](U64) & 0xFF) << 16;
    if (remaining >= 3) tail_word |= (data[pos+2](U64) & 0xFF) << 8;
    sum += tail_word;
  }
  return sum & 0xFFFFFFFF;
}

// Builds the simplest possible valid Fossil-format delta: a header
// (target length), one literal segment holding the ENTIRE target (no
// copy segments - this probe proves the format's mechanics, not a
// real diff algorithm), and a trailer (checksum). `source`/
// `source_len` are unused by this trivial encoder (a real diff
// algorithm would use them to find copy ranges) but kept in the
// signature so callers don't need to change when a real encoder
// replaces this one.
U0 FossilDeltaMakeTrivial(U8 *source, I64 source_len, U8 *target, I64 target_len,
                            U8 *delta_out, I64 *delta_len_out)
{
  I64 len = 0;
  FossilPutInt(target_len, delta_out, &len);
  delta_out[len++] = '\n';

  FossilPutInt(target_len, delta_out, &len);
  delta_out[len++] = ':';
  I64 i;
  for (i=0; i<target_len; i++) delta_out[len++] = target[i];

  // `sum` is a U32 function-return value (Canon.HC's own separately
  // documented risk case - a function declared to return a
  // narrower-than-64-bit type doesn't reliably truncate for the
  // caller) - cast to (U64) then masked, not trusted as already clean
  // and not cast directly to (I64).
  U32 sum = FossilChecksum(target, target_len);
  FossilPutInt((sum(U64) & 0xFFFFFFFF), delta_out, &len);
  delta_out[len++] = ';';

  *delta_len_out = len;
}

// Below this match length (bytes), a match isn't worth encoding as a
// copy segment - the segment's own overhead (length digits + '@' +
// source-offset digits + ',') can exceed what it saves versus just
// keeping those bytes literal. Not tuned against real data, just a
// small, defensible floor (Fossil's own real implementation uses a
// rolling hash over 16-byte blocks for this same reason, at a
// different scale - not replicated here, see the file's own header
// note on scope).
#define FOSSIL_MIN_COPY_LEN 4

// A real (if minimal) diff: finds the single longest matching
// substring between `source` and `target` (a plain O(source_len *
// target_len) double scan - fine at this project's own established
// "no premature optimization" scale, same stance as every linear scan
// already in Index.HC) and, if it's at least FOSSIL_MIN_COPY_LEN
// bytes, encodes the delta as [literal prefix][copy segment][literal
// suffix] instead of `FossilDeltaMakeTrivial`'s always-one-big-literal
// approach. Falls back to that same all-literal shape if no match
// meets the threshold (including source_len==0 or target_len==0).
//
// ADR 0008 (experiments/82-fossil-real-diff/): this is genuinely a
// *first* real diff algorithm, not the format's final one - it finds
// exactly one copy segment (the single longest match), not a real
// multi-hunk diff. A target edited in two separate, non-adjacent
// places still only gets ONE copy segment; the other unchanged region
// stays literal. Real, useful compression for the common
// single-edit-region case; a real limitation for anything more
// complex, honestly scoped rather than oversold.
// Shared by `FossilDeltaMakeReal` and `FossilSimilarityPercent` - the
// same O(source_len * target_len) longest-match scan, extracted so
// the similarity measure and the actual encoder can never quietly
// drift apart (two independent copies of this scan would be a real
// risk of "the similarity score doesn't match what the encoder would
// actually produce").
U0 FossilFindLongestMatch(U8 *source, I64 source_len, U8 *target, I64 target_len,
                          I64 *best_src_off_out, I64 *best_tgt_off_out, I64 *best_len_out)
{
  I64 best_src_off = -1, best_tgt_off = -1, best_len = 0;
  I64 si, ti;
  for (si=0; si<source_len; si++) {
    for (ti=0; ti<target_len; ti++) {
      I64 match_len = 0;
      while (si+match_len < source_len && ti+match_len < target_len &&
             source[si+match_len] == target[ti+match_len]) match_len++;
      if (match_len > best_len) {
        best_len = match_len;
        best_src_off = si;
        best_tgt_off = ti;
      }
    }
  }
  *best_src_off_out = best_src_off;
  *best_tgt_off_out = best_tgt_off;
  *best_len_out = best_len;
}

U0 FossilDeltaMakeReal(U8 *source, I64 source_len, U8 *target, I64 target_len,
                       U8 *delta_out, I64 *delta_len_out)
{
  I64 best_src_off, best_tgt_off, best_len;
  FossilFindLongestMatch(source, source_len, target, target_len,
                         &best_src_off, &best_tgt_off, &best_len);

  I64 len = 0;
  FossilPutInt(target_len, delta_out, &len);
  delta_out[len++] = '\n';

  I64 i;
  if (best_len >= FOSSIL_MIN_COPY_LEN) {
    if (best_tgt_off > 0) {
      FossilPutInt(best_tgt_off, delta_out, &len);
      delta_out[len++] = ':';
      for (i=0; i<best_tgt_off; i++) delta_out[len++] = target[i];
    }
    FossilPutInt(best_len, delta_out, &len);
    delta_out[len++] = '@';
    FossilPutInt(best_src_off, delta_out, &len);
    delta_out[len++] = ',';
    I64 suffix_start = best_tgt_off + best_len;
    I64 suffix_len = target_len - suffix_start;
    if (suffix_len > 0) {
      FossilPutInt(suffix_len, delta_out, &len);
      delta_out[len++] = ':';
      for (i=0; i<suffix_len; i++) delta_out[len++] = target[suffix_start+i];
    }
  } else {
    // No match worth encoding - same all-literal shape as
    // FossilDeltaMakeTrivial.
    FossilPutInt(target_len, delta_out, &len);
    delta_out[len++] = ':';
    for (i=0; i<target_len; i++) delta_out[len++] = target[i];
  }

  U32 sum = FossilChecksum(target, target_len);
  FossilPutInt((sum(U64) & 0xFFFFFFFF), delta_out, &len);
  delta_out[len++] = ';';

  *delta_len_out = len;
}

// Shared rename-detection threshold (experiments/84-fuzzy-rename-detection/,
// experiments/85-status-fuzzy-rename/): git's own real default
// (`-M50%`), not an invented number. Lives here, not in either real
// caller (`Offer.HC`/`Status.HC`), so both use the exact same value -
// defined once, before both of them in build order, since a `#define`
// is no more forward-declarable across this project's own single
// concatenated build than a function is.
#define FOSSIL_RENAME_SIMILARITY_THRESHOLD 50

// A real similarity measure, in whole percent (0-100), between
// `source` and `target`: the fraction of `target` covered by the
// single longest match `FossilFindLongestMatch` would find - the same
// scan `FossilDeltaMakeReal` itself uses to decide whether a copy
// segment is worth encoding, reused here rather than reimplemented, so
// this score can never silently diverge from what the real encoder
// would actually do. Matches git's own real "similarity index" idea
// (a percentage a rename-detection caller can threshold against, e.g.
// git's own default `-M50%`) but - like `FossilDeltaMakeReal` itself -
// only ever measures ONE contiguous match, not true multi-hunk
// similarity: a file with several separate small edits scattered
// through it will score lower here than a real multi-hunk diff tool
// would report, an honest limitation inherited directly from the
// diff algorithm this reuses. Returns 0 for a zero-length target
// (nothing to be similar to) rather than dividing by zero.
I64 FossilSimilarityPercent(U8 *source, I64 source_len, U8 *target, I64 target_len)
{
  if (target_len == 0) return 0;
  I64 best_src_off, best_tgt_off, best_len;
  FossilFindLongestMatch(source, source_len, target, target_len,
                         &best_src_off, &best_tgt_off, &best_len);
  return (best_len * 100) / target_len;
}

// Parses and applies a Fossil-format delta against `source` (used for
// real copy segments - `FossilDeltaMakeReal` now produces these; this
// function's own copy-segment handling was written and parse-tested
// before that encoder existed, per its own original comment, and
// needed no changes once a real encoder started emitting them),
// writing the reconstructed target into `target_out` and its length
// into *target_len_out. Returns FALSE (nothing trustworthy written)
// if the delta is malformed or the trailer checksum doesn't match the
// reconstructed target - the same "verify, don't just trust" pattern
// this project's own `hgit check`/`ArchiveVerify` already use.
Bool FossilDeltaApply(U8 *source, I64 source_len, U8 *delta, I64 delta_len,
                       U8 *target_out, I64 *target_len_out)
{
  I64 pos = 0;
  I64 declared_target_len;
  I64 n = FossilGetInt(delta, pos, &declared_target_len);
  if (n == 0) return FALSE;
  pos += n;
  if (delta[pos] != '\n') return FALSE;
  pos += 1;

  // The loop terminates once `tlen` reaches the header's own declared
  // target length - NOT by scanning for a ';' delimiter. An earlier
  // version used `delta[pos] != ';'` as the "more segments?" check,
  // which is genuinely ambiguous: the trailer's own checksum digits
  // are never ';' either (only the character after all of them is),
  // so it misread the checksum as a bogus extra segment's length and
  // overran both `delta` and `target_out` - a real, reproduced VM
  // reset, not just a logic error (experiments/68-fossil-delta-format/).
  I64 tlen = 0;
  while (tlen < declared_target_len) {
    I64 seg_len;
    I64 an = FossilGetInt(delta, pos, &seg_len);
    if (an == 0) return FALSE;
    pos += an;
    U8 op = delta[pos];
    pos += 1;
    if (op == ':') {
      I64 li;
      for (li=0; li<seg_len; li++) target_out[tlen++] = delta[pos+li];
      pos += seg_len;
    } else if (op == '@') {
      // Copy segment: seg_len bytes from offset (read next int) in
      // source. Not produced by FossilDeltaMakeTrivial yet, but
      // parsed here so this function is ready for a real diff
      // encoder without changing its own contract.
      I64 srcoff;
      I64 on = FossilGetInt(delta, pos, &srcoff);
      if (on == 0) return FALSE;
      pos += on;
      if (delta[pos] != ',') return FALSE;
      pos += 1;
      I64 ci;
      for (ci=0; ci<seg_len; ci++) target_out[tlen++] = source[srcoff+ci];
    } else {
      return FALSE; // unknown segment op - malformed delta
    }
  }

  // Trailer is <checksum-digits>';' - the checksum integer comes
  // FIRST, then the ';' terminator. An earlier version checked for
  // ';' before reading the checksum, which is backwards (`delta[pos]`
  // right after the segment loop is the checksum's own first digit,
  // never ';' itself) and always failed here.
  I64 declared_checksum;
  I64 cn = FossilGetInt(delta, pos, &declared_checksum);
  if (cn == 0) return FALSE;
  pos += cn;
  if (pos >= delta_len || delta[pos] != ';') return FALSE;
  pos += 1;

  if (tlen != declared_target_len) return FALSE;
  // real_checksum is a function's own U32 return value - cast to
  // (U64) then masked, matching FossilDeltaMakeTrivial's own encode
  // side, not cast directly to (I64). Compared as U32-vs-U32
  // (declared_checksum32), not I64-vs-(U64-masked) - a mixed-
  // signedness comparison here was a real, tested suspect for ADR
  // 0008's caller-shape-sensitivity bug (experiments/79-fossil-checksum-isolation/):
  // ruled out, the known-failing reproduction still fails identically
  // with this cleaner comparison. Kept anyway as strictly clearer.
  U32 declared_checksum32 = declared_checksum & 0xFFFFFFFF;
  U32 real_checksum = FossilChecksum(target_out, tlen);
  if (real_checksum != declared_checksum32) return FALSE;

  *target_len_out = tlen;
  return TRUE;
}
// MergeBase.HC — finds the lowest common ancestor of two commits.
//
// Real prerequisite chain, same "primitive first, then a real CLI
// decision" pattern ADR 0010's own probes 90/91 established: probe 97
// confirmed hgit's object model already supports a real multi-parent
// (merge) commit with zero code changes; this is the next real,
// separate, standalone piece ADR 0011's own `hgit merge` command needs
// - finding where two diverged paths' own histories actually split,
// before any real three-way tree merge can happen. Verified standalone
// (experiments/98-merge-base/) before any real command wires it in.
//
// Probe 109 (experiments/109-merge-base-stale-ancestor/): this
// function originally walked each commit's own parent[0] chain only -
// documented at the time as a deliberate limitation for "genuine
// criss-cross histories," with "no evidence yet hgit's own real usage
// needs" anything stronger. That was wrong once real merge commits
// existed: parent[0]-only isn't just ambiguous in a criss-cross case,
// it's flatly WRONG the moment either side's history passes through a
// real merge commit at all - a merge's own SECOND (and later) parent
// is invisible to a parent[0]-only walk, so a real, more-recent common
// ancestor reachable only through that side is silently skipped in
// favor of an older, stale one. Probe 109 built a real, minimal
// reproduction (two merges, the second one merging a path forked from
// the FIRST merge's non-"ours" side) and confirmed a real, wrong
// `MERGE_CONFLICT` where a clean, correct three-way merge should have
// happened - not a hypothetical, an actual observed failure.
//
// Fixed here: a real ancestor-SET walk considering EVERY parent (not
// just parent[0]) from each side. `CollectAllAncestors` does a real
// BFS from `hash_a` over the full parent DAG, producing hash_a's
// complete ancestor set. `FindMergeBase` itself then does a real BFS
// from `hash_b`, level by level over ALL its own parents too,
// returning the first node found in hash_a's ancestor set - the first
// match during a breadth-first walk from b is the closest (to b)
// common ancestor, a real, practical proxy for "most recent" that
// correctly reaches a merge's non-"ours" parent, not the exact
// Git-style "recursive merge-base" algorithm (which itself falls back
// to a virtual merge of multiple candidate bases in a genuine
// criss-cross case). Genuine criss-cross ambiguity (multiple real
// lowest common ancestors, no single correct answer) remains a real,
// separate, deliberately out-of-scope limitation - unrelated to and
// not fixed by this probe, which only fixes "ignoring real ancestry
// that was reachable all along."
//
// Depends on Canon.HC, Object.HC, Commit.HC, Index.HC.

// Real, minimal linear-scan "hash set" helpers - the same style this
// project already uses for name/hash arrays throughout (Status.HC's
// own new_matched/del_matched, etc.), not a new data structure. Both
// take a MAlloc'd `set` (idx_count*64+64 bytes, sized by the same real
// upper bound - total distinct objects in the repo - every other
// dynamic buffer in this file already uses).
Bool HashSetContains(U8 *set, I64 count, U8 *hash)
{
  I64 i, j;
  for (i=0; i<count; i++) {
    Bool same = TRUE;
    for (j=0; j<64; j++) if (set[i*64+j] != hash[j]) same = FALSE;
    if (same) return TRUE;
  }
  return FALSE;
}

// Adds `hash` to `set` if not already present. Returns TRUE if it was
// actually added (a real new node this BFS hasn't visited yet).
Bool HashSetAdd(U8 *set, I64 *count, U8 *hash)
{
  if (HashSetContains(set, *count, hash)) return FALSE;
  I64 i;
  for (i=0; i<64; i++) set[(*count)*64+i] = hash[i];
  (*count)++;
  return TRUE;
}

// A real BFS from `start_hash` over EVERY parent edge (not just
// parent[0]) - the complete ancestor set (including `start_hash`
// itself). `out_hashes` doubles as both the growing result set and
// the BFS frontier (append-only, scanned by index `qi` below) - no
// separate queue needed since nothing is ever removed, only appended.
U0 CollectAllAncestors(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                       U8 *start_hash, U8 *out_hashes, I64 *out_count)
{
  *out_count = 0;
  HashSetAdd(out_hashes, out_count, start_hash);
  I64 qi = 0;
  while (qi < *out_count) {
    U8 *cur = out_hashes + qi*64;
    I64 off_rel;
    if (IndexLookup(idx_hashes, idx_offsets, idx_count, cur, &off_rel)) {
      I64 off = 16 + off_rel;
      if (rbuf[off+8] == OBJ_COMMIT) {
        U8 *content = rbuf + off + 9;
        U8 pcount = CommitParentCount(content);
        U8 pidx;
        for (pidx=0; pidx<pcount; pidx++) {
          U8 *parent = CommitParentHash(content, pidx);
          HashSetAdd(out_hashes, out_count, parent);
        }
      }
    }
    qi++;
  }
}

Bool FindMergeBase(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                   U8 *hash_a, U8 *hash_b, U8 *out_base_hash)
{
  // hash_a's complete ancestor set (every real parent edge, not just
  // parent[0]) - MAlloc'd from idx_count, the same real upper bound
  // (total distinct objects in this repo) every other dynamic buffer
  // in this codebase already uses (no guessed cap, ADR 0007's own
  // discipline).
  U8 *ancestors_a = MAlloc(idx_count*64 + 64);
  I64 ancestors_a_count = 0;
  CollectAllAncestors(rbuf, idx_hashes, idx_offsets, idx_count,
                      hash_a, ancestors_a, &ancestors_a_count);

  // A real BFS from hash_b, level by level, over EVERY parent edge -
  // `queue_b` doubles as both the visited set (so a diamond-shaped
  // history never re-expands the same node twice) and the frontier,
  // same append-and-scan technique as CollectAllAncestors above. The
  // first node found in hash_a's ancestor set during this breadth-
  // first walk is the closest (to b) common ancestor - not
  // necessarily THE unique lowest common ancestor in a genuine
  // criss-cross case (still a real, separate, undecided question),
  // but always at least as correct as the old parent[0]-only walk,
  // and correctly reaches a merge's non-"ours" parent, which the old
  // walk never did.
  U8 *queue_b = MAlloc(idx_count*64 + 64);
  I64 queue_b_count = 0;
  HashSetAdd(queue_b, &queue_b_count, hash_b);

  Bool found = FALSE;
  I64 qi = 0;
  while (qi < queue_b_count && !found) {
    U8 *cur = queue_b + qi*64;
    if (HashSetContains(ancestors_a, ancestors_a_count, cur)) {
      I64 hi;
      for (hi=0; hi<64; hi++) out_base_hash[hi] = cur[hi];
      found = TRUE;
    } else {
      I64 off_rel;
      if (IndexLookup(idx_hashes, idx_offsets, idx_count, cur, &off_rel)) {
        I64 off = 16 + off_rel;
        if (rbuf[off+8] == OBJ_COMMIT) {
          U8 *content = rbuf + off + 9;
          U8 pcount = CommitParentCount(content);
          U8 pidx;
          for (pidx=0; pidx<pcount; pidx++) {
            U8 *parent = CommitParentHash(content, pidx);
            HashSetAdd(queue_b, &queue_b_count, parent);
          }
        }
      }
      qi++;
    }
  }

  Free(ancestors_a);
  Free(queue_b);
  return found;
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

// Probe 113 (experiments/113-check-format-version/, FORMAT.md's own
// "Versioning policy" section): a new repo now starts at
// `format_version` 2, not 1 - a real, deliberate bump correcting a
// real gap this project found in its own practice: version 1 was
// still being written for every new repo despite at least three real,
// documented breaking changes to what it means since (ADR 0004's
// entity-ID field, ADR 0010's recursive trees, ADR 0011's multi-parent
// commits). No reader anywhere branches on the literal version number
// (confirmed by direct search before this change), so this is purely
// a correction to what gets WRITTEN, not a new migration mechanism -
// no real evidence yet that one is needed (no released users, no repo
// has ever had to survive across one of these format changes). A
// version-1 repo (every repo any test/probe in this project has ever
// built) is not migrated and still reads back fine - HgsReadHeader
// doesn't reject it, and no code path treats the two differently.

// Returns TRUE on success, FALSE if a file already exists at `path`
// (existing repos/files are never overwritten by init).
Bool HgitInit(U8 *path)
{
  I64 existing_size;
  U8 *existing = FileRead(path, &existing_size);
  if (existing != NULL) return FALSE;
  U8 header[16];
  HgsWriteHeader(header, 2, 0);
  FileWrite(path, header, 16);
  return TRUE;
}
// Paths.HC — named paths (hgit's branch equivalent), per the brief's
// `hgit path list/new/go/close` vocabulary. Design decisions written
// up retroactively in `docs/adr/0012-named-paths.md`.
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
// Tree.HC, Commit.HC, Index.HC, Fossil.HC, WorkDir.HC (the whole
// hgit-core object layer plus the CLI pieces built so far).
//
// Both tree-entry walks (TreeFindEntry's new signature, and the manual
// pass-2 walk below) updated for ADR 0004's 8-byte entity ID field
// (experiments/49-entity-id/).
//
// ADR 0009 addendum (experiments/71-status-rename-surfacing/): status
// now also surfaces exact-content renames, not just NEW/MODIFIED/
// UNCHANGED/DELETED. A NEW-on-disk file and a DELETED tree entry that
// share the same content hash are reported as a single STATUS_RENAMED
// <old> -> <new> line instead of two separate NEW/DELETED lines - the
// same exact-content matching Offer.HC already uses to carry an entity
// ID forward (TreeFindEntryByHash), just applied here to working-dir
// vs HEAD-tree status instead of old-tree vs new-tree at offer time.
// This only *reports* the match; it doesn't change what gets committed
// - the next real `hgit offer` still does its own independent rename
// detection when the file is actually offered.
//
// ADR 0009 addendum (experiments/85-status-fuzzy-rename/): a second
// rename pass, for renames WITH an edit - reusing Fossil's similarity
// measure (ADR 0008, `experiments/83-fossil-similarity/`) the same
// way `Offer.HC`'s own fuzzy detection does (probe 84), same git-style
// `-M50%` threshold (`Fossil.HC`'s own `FOSSIL_RENAME_SIMILARITY_THRESHOLD`).
// Runs only against pairs the exact-hash pass above left unmatched.
// Now depends on `Fossil.HC` too (for the similarity call).

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

  // ADR 0007's same fix, applied here (experiments/62-index-buffer-sweep/):
  // idx_hashes/idx_offsets used to be fixed [64*64]/[64] stack arrays, a
  // hardcoded 64-object-in-the-whole-repo cap - MAlloc'd from `rcount`
  // (exact, from the .HGS header) instead. Only one exit path here
  // after this point, freed right before it.
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
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
  // disk right now. NEW files aren't printed immediately anymore - per
  // the ADR 0009 addendum above, they're buffered (name + hash) so
  // pass 2's deleted entries can be checked against them for an
  // exact-content rename match before anything is printed.
  I64 disk_count = 0;
  CDirEntry *count_de = FilesFind(find_mask, 0);
  CDirEntry *count_de1 = count_de;
  while (count_de) { disk_count++; count_de = count_de->next; }
  DirTreeDel(count_de1);

  U8 *new_names = MAlloc(disk_count*256 + 256);   // one 256-byte slot each
  U8 *new_hashes = MAlloc(disk_count*64 + 64);
  Bool *new_matched = MAlloc(disk_count + 1);
  // ADR 0009 addendum (experiments/85-status-fuzzy-rename/): a fuzzy
  // rename check needs each candidate's real CONTENT, not just its
  // hash - one 512-byte slot each. Probe 108 (experiments/108-status-large-file-support/):
  // this fixed per-slot stride is still real (a jagged/variable-offset
  // layout would be a bigger structural change than this probe scopes
  // to), so a candidate whose own content doesn't fit in one slot
  // simply isn't buffered for FUZZY matching - `new_content_lens[ni]`
  // is set to 0 for it (safe: `FossilSimilarityPercent` against a
  // zero-length target never matches), not skipped entirely - it still
  // gets a real hash (for exact-match rename detection) and a real
  // NEW/MODIFIED/UNCHANGED classification, unlike before this probe.
  U8 *new_contents = MAlloc(disk_count*512 + 512);
  I64 *new_content_lens = MAlloc(disk_count*8 + 8);
  I64 new_count = 0;

  CDirEntry *tmpde = FilesFind(find_mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 fsize;
    U8 *fbuf = FileRead(tmpde->full_name, &fsize);

    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;

    // Probe 108: was a fixed `tagged[512]` stack buffer (a file over
    // 511 bytes overflowed it - guarded before this probe by skipping
    // the whole file with `STATUS_TOO_LARGE_TO_CHECK`, reporting
    // nothing else about it at all). `MAlloc`'d at the file's own real
    // size instead, same fix as probes 105-107's own version - a large
    // file now gets a real hash and a real NEW/MODIFIED/UNCHANGED
    // classification; only fuzzy-rename buffering (below) keeps a
    // real, separate, smaller size limit (`new_contents`'s own fixed
    // per-slot stride).
    U8 *tagged = MAlloc(fsize+1);
    tagged[0] = OBJ_BLOB;
    I64 i;
    for (i=0; i<fsize; i++) tagged[1+i] = fbuf[i];
    U8 file_hash[64];
    B2Hash512Any(tagged, fsize+1, file_hash);
    Free(tagged);

    U8 tree_type;
    U8 tree_entry_hash[64];
    U64 tree_entity_id;
    Bool in_tree = TreeFindEntry(tree_content, tree_content_len,
                                  tmpde->full_name+name_start, name_len,
                                  &tree_type, tree_entry_hash, &tree_entity_id);
    if (!in_tree) {
      // Buffered, not printed - a possible rename source. Names over
      // 254 chars are truncated to fit the fixed 256-byte slot; this
      // repo's own 33-char path ceiling (ADR 0003) means a real name
      // this project has to handle never gets close to that anyway.
      I64 cap = name_len; if (cap > 254) cap = 254;
      for (i=0; i<cap; i++) new_names[new_count*256+i] = tmpde->full_name[name_start+i];
      new_names[new_count*256+cap] = 0;
      for (i=0; i<64; i++) new_hashes[new_count*64+i] = file_hash[i];
      if (fsize+1 <= 512) {
        for (i=0; i<fsize; i++) new_contents[new_count*512+i] = fbuf[i];
        new_content_lens[new_count] = fsize;
      } else {
        new_content_lens[new_count] = 0; // too large to buffer for fuzzy matching - see comment above
      }
      new_matched[new_count] = FALSE;
      new_count++;
    } else {
      Bool same = TRUE;
      for (i=0; i<64; i++) if (file_hash[i] != tree_entry_hash[i]) same = FALSE;
      if (same) CommPrint(1, "STATUS_UNCHANGED ");
      else CommPrint(1, "STATUS_MODIFIED ");
      for (j=name_start; tmpde->full_name[j]; j++) CommPrint(1, "%c", tmpde->full_name[j]);
      CommPrint(1, "\n");
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);

  // Pass 2: deleted - walk every tree entry, check it still exists on
  // disk. This is the only place hgit-core needs "everything the tree
  // says should exist," so it's done inline here rather than adding a
  // generic tree-iteration API to Tree.HC for a single caller. Same as
  // pass 1, DELETED candidates are buffered (name + hash) instead of
  // printed immediately, so they can be checked against `new_names`/
  // `new_hashes` for a rename match first.
  U32 tcount = GetU32LE(tree_content, 0);
  U8 *del_names = MAlloc(tcount*256 + 256);
  U8 *del_hashes = MAlloc(tcount*64 + 64);
  Bool *del_matched = MAlloc(tcount + 1);
  I64 del_count = 0;

  I64 tpos = 4;
  U32 te;
  for (te=0; te<tcount; te++) {
    U8 tname_len = tree_content[tpos]; tpos += 1;
    U8 *tname = tree_content + tpos; tpos += tname_len;
    tpos += 1; // skip type
    U8 *thash = tree_content + tpos; tpos += 64; // keep for rename match
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
      I64 dcap = tname_len; if (dcap > 254) dcap = 254;
      for (m=0; m<dcap; m++) del_names[del_count*256+m] = tname[m];
      del_names[del_count*256+dcap] = 0;
      for (m=0; m<64; m++) del_hashes[del_count*64+m] = thash[m];
      del_matched[del_count] = FALSE;
      del_count++;
    }
  }

  // Rename match: exact-content only, same "first match wins"
  // simplification ADR 0009 already documents for Offer.HC's own
  // TreeFindEntryByHash - a genuine ambiguity (two deleted files with
  // identical content, one new file matching both) picks whichever
  // deleted entry is scanned first, not disambiguated further here.
  I64 di, ni;
  for (di=0; di<del_count; di++) {
    for (ni=0; ni<new_count; ni++) {
      Bool hmatch = !new_matched[ni];
      I64 hi;
      if (hmatch) for (hi=0; hi<64; hi++) if (del_hashes[di*64+hi] != new_hashes[ni*64+hi]) hmatch = FALSE;
      if (hmatch) {
        CommPrint(1, "STATUS_RENAMED %s -> %s\n", del_names+di*256, new_names+ni*256);
        new_matched[ni] = TRUE;
        del_matched[di] = TRUE;
        ni = new_count; // matched - stop scanning new[] for this del entry
      }
    }
  }

  // ADR 0009 addendum (experiments/85-status-fuzzy-rename/): a second
  // pass for renames WITH an edit - exact hash already failed above,
  // so try Fossil's similarity measure (ADR 0008, probe 83) against
  // each still-unmatched pair, same git-style -M50% threshold Offer.HC
  // already uses (probe 84). Each deleted entry's real content is
  // resolved on demand via the index already built above - deleted
  // candidates only ever store a hash, not their own content buffer,
  // since (unlike new-on-disk files) their bytes already live in the
  // repo's own archive and don't need a second copy. Same "first/best
  // match wins" simplification as the exact-hash pass just above.
  for (di=0; di<del_count; di++) {
    if (!del_matched[di]) {
      I64 del_off_rel;
      if (IndexLookup(idx_hashes, idx_offsets, idx_count, del_hashes+di*64, &del_off_rel)) {
        I64 del_off = 16 + del_off_rel;
        U64 del_rec_len = GetU64LE(rbuf, del_off);
        U8 *del_content = rbuf + del_off + 9; // skip the OBJ_BLOB type tag
        I64 del_content_len = del_rec_len - 1;

        I64 best_ni = -1, best_sim = -1;
        for (ni=0; ni<new_count; ni++) {
          if (!new_matched[ni]) {
            I64 sim = FossilSimilarityPercent(del_content, del_content_len,
                                              new_contents+ni*512, new_content_lens[ni]);
            if (sim > best_sim) { best_sim = sim; best_ni = ni; }
          }
        }
        if (best_ni >= 0 && best_sim >= FOSSIL_RENAME_SIMILARITY_THRESHOLD) {
          CommPrint(1, "STATUS_RENAMED %s -> %s\n", del_names+di*256, new_names+best_ni*256);
          new_matched[best_ni] = TRUE;
          del_matched[di] = TRUE;
        }
      }
    }
  }

  for (ni=0; ni<new_count; ni++) {
    if (!new_matched[ni]) CommPrint(1, "STATUS_NEW %s\n", new_names+ni*256);
  }
  for (di=0; di<del_count; di++) {
    if (!del_matched[di]) CommPrint(1, "STATUS_DELETED %s\n", del_names+di*256);
  }

  CommPrint(1, "STATUS_END\n");
  Free(idx_hashes);
  Free(idx_offsets);
  Free(new_names);
  Free(new_hashes);
  Free(new_contents);
  Free(new_content_lens);
  Free(new_matched);
  Free(del_names);
  Free(del_hashes);
  Free(del_matched);
}

// ADR 0010 addendum (experiments/95-statustree/): `hgit statustree
// <repo> <dir_path>` - a real, separate command, not a change to
// `hgit status`'s own `find_mask`/`dir_prefix` semantics (same
// CLI-semantics decision `offertree` already made for `offer`, and
// `Diff.HC`'s own recursion already made for `diff`). Closes the last
// item on ADR 0010's own "rendering-command awareness of nested
// trees" list.
//
// `StatusTreeWalk` recurses one real directory level at a time -
// same generic-per-object-type pattern this project already
// established (`Check.HC`'s `CheckMarkReachable`, `See.HC`'s
// `SeePrintTreeEntries`, `Diff.HC`'s `DiffPrintTreeChanges`): a real
// subdirectory on disk with a matching, same-typed tree entry is
// recursed into; a real subdirectory with no tree match (or a
// type-changed match) is recursed against an empty tree/reported
// `STATUS_TYPE_CHANGED`; a tree-only entry (a subdirectory that
// existed before but is no longer on disk at all) is recursed against
// an empty real directory listing, so every real entry it used to
// contain gets its own `STATUS_DELETED <path>` line. Rename detection
// (exact-hash, then fuzzy) stays scoped to one directory level at a
// time and blob-only, exactly like `Diff.HC`'s own - cross-directory
// rename detection remains ADR 0010's own deliberately deferred item.
U0 StatusTreeWalk(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                  U8 *dir_path, U8 *tree_content, I64 tree_content_len,
                  U8 *prefix)
{
  U8 mask[256];
  StrPrint(mask, "%s*", dir_path);

  I64 disk_count = 0;
  CDirEntry *count_de = FilesFind(mask, 0);
  CDirEntry *count_de1 = count_de;
  while (count_de) { disk_count++; count_de = count_de->next; }
  DirTreeDel(count_de1);

  U8 *new_names = MAlloc(disk_count*256 + 256);
  U8 *new_hashes = MAlloc(disk_count*64 + 64);
  Bool *new_matched = MAlloc(disk_count + 1);
  U8 *new_contents = MAlloc(disk_count*512 + 512);
  I64 *new_content_lens = MAlloc(disk_count*8 + 8);
  I64 new_count = 0;

  U32 tcount = 0;
  if (tree_content != NULL) tcount = GetU32LE(tree_content, 0);
  U8 *del_names = MAlloc(tcount*256 + 256);
  U8 *del_hashes = MAlloc(tcount*64 + 64);
  Bool *del_matched = MAlloc(tcount + 1);
  I64 del_count = 0;

  I64 i;
  CDirEntry *tmpde = FilesFind(mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;
    Bool is_dot = StrCmp(tmpde->full_name+name_start, ".") == 0;
    Bool is_dotdot = StrCmp(tmpde->full_name+name_start, "..") == 0;

    if (!is_dot && !is_dotdot) {
      U8 full_name[256];
      I64 fi = 0, fj;
      for (fj=0; prefix[fj]; fj++) full_name[fi++] = prefix[fj];
      I64 cap0 = name_len; if (fi+cap0 > 254) cap0 = 254-fi;
      for (fj=0; fj<cap0; fj++) full_name[fi++] = tmpde->full_name[name_start+fj];
      full_name[fi] = 0;

      if (tmpde->attr & 16) {
        U8 old_type;
        U8 old_hash[64];
        U64 old_entity_id;
        Bool found = FALSE;
        if (tree_content != NULL) {
          found = TreeFindEntry(tree_content, tree_content_len,
                                tmpde->full_name+name_start, name_len,
                                &old_type, old_hash, &old_entity_id);
        }
        U8 subdir_path[256];
        I64 spi = 0, spj;
        for (spj=0; tmpde->full_name[spj]; spj++) subdir_path[spi++] = tmpde->full_name[spj];
        subdir_path[spi++] = '/'; subdir_path[spi] = 0;

        if (found && old_type == OBJ_TREE) {
          U8 *sub_tree_content_a = NULL; I64 sub_tree_len_a = 0;
          I64 sub_off_rel_a;
          if (IndexLookup(idx_hashes, idx_offsets, idx_count, old_hash, &sub_off_rel_a)) {
            I64 sub_off_a = 16 + sub_off_rel_a;
            U64 sub_rec_len_a = GetU64LE(rbuf, sub_off_a);
            sub_tree_content_a = rbuf + sub_off_a + 9;
            sub_tree_len_a = sub_rec_len_a - 1;
          }
          U8 sub_prefix_a[256];
          I64 pia = 0, pja;
          for (pja=0; full_name[pja]; pja++) sub_prefix_a[pia++] = full_name[pja];
          sub_prefix_a[pia++] = '/'; sub_prefix_a[pia] = 0;
          StatusTreeWalk(rbuf, idx_hashes, idx_offsets, idx_count,
                        subdir_path, sub_tree_content_a, sub_tree_len_a, sub_prefix_a);
        } else if (found) {
          CommPrint(1, "STATUS_TYPE_CHANGED %s\n", full_name);
        } else {
          U8 sub_prefix_b[256];
          I64 pib = 0, pjb;
          for (pjb=0; full_name[pjb]; pjb++) sub_prefix_b[pib++] = full_name[pjb];
          sub_prefix_b[pib++] = '/'; sub_prefix_b[pib] = 0;
          StatusTreeWalk(rbuf, idx_hashes, idx_offsets, idx_count,
                        subdir_path, NULL, 0, sub_prefix_b);
        }
      } else {
        I64 fsize;
        U8 *fbuf = FileRead(tmpde->full_name, &fsize);
        {
          // Probe 108 (experiments/108-status-large-file-support/):
          // was `if (fsize+1 > 512) STATUS_TOO_LARGE_TO_CHECK` guarding
          // a fixed `tagged[512]` stack buffer - `MAlloc`'d at the
          // file's own real size instead, same fix as the flat `hgit
          // status` version above. Only fuzzy-rename buffering below
          // keeps a real, separate size limit (`new_contents`'s own
          // fixed per-slot stride).
          U8 *tagged = MAlloc(fsize+1);
          tagged[0] = OBJ_BLOB;
          for (i=0; i<fsize; i++) tagged[1+i] = fbuf[i];
          U8 file_hash[64];
          B2Hash512Any(tagged, fsize+1, file_hash);
          Free(tagged);

          U8 tree_type;
          U8 tree_entry_hash[64];
          U64 tree_entity_id;
          Bool in_tree = FALSE;
          if (tree_content != NULL) {
            in_tree = TreeFindEntry(tree_content, tree_content_len,
                                    tmpde->full_name+name_start, name_len,
                                    &tree_type, tree_entry_hash, &tree_entity_id);
          }
          if (in_tree && tree_type == OBJ_BLOB) {
            Bool same_c = TRUE;
            for (i=0; i<64; i++) if (file_hash[i] != tree_entry_hash[i]) same_c = FALSE;
            if (!same_c) CommPrint(1, "STATUS_MODIFIED %s\n", full_name);
          } else if (in_tree) {
            CommPrint(1, "STATUS_TYPE_CHANGED %s\n", full_name);
          } else {
            I64 cap = fi; if (cap > 254) cap = 254;
            for (i=0; i<cap; i++) new_names[new_count*256+i] = full_name[i];
            new_names[new_count*256+cap] = 0;
            for (i=0; i<64; i++) new_hashes[new_count*64+i] = file_hash[i];
            if (fsize+1 <= 512) {
              for (i=0; i<fsize; i++) new_contents[new_count*512+i] = fbuf[i];
              new_content_lens[new_count] = fsize;
            } else {
              new_content_lens[new_count] = 0; // too large to buffer for fuzzy matching
            }
            new_matched[new_count] = FALSE;
            new_count++;
          }
        }
      }
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);

  // Deletion pass: a tree-only entry (no longer on disk at all, or on
  // disk with a different kind) at THIS level. Existence is checked
  // by real kind, not just FileRead success, since a tree entry can
  // now legitimately be a directory too (ADR 0010) - reusing the
  // already-real check_path convention every prior version of this
  // function used, extended with a FilesFind-based directory check.
  if (tree_content != NULL) {
    I64 tpos = 4;
    U32 te;
    for (te=0; te<tcount; te++) {
      U8 tname_len = tree_content[tpos]; tpos += 1;
      U8 *tname = tree_content + tpos; tpos += tname_len;
      U8 ttype = tree_content[tpos]; tpos += 1;
      U8 *thash = tree_content + tpos; tpos += 64;
      tpos += 8; // entity_id

      U8 check_path[256];
      I64 k = 0;
      while (dir_path[k]) { check_path[k] = dir_path[k]; k++; }
      I64 m;
      for (m=0; m<tname_len; m++) check_path[k+m] = tname[m];
      check_path[k+tname_len] = 0;

      U8 full_tname[256];
      I64 fti = 0, ftj;
      for (ftj=0; prefix[ftj]; ftj++) full_tname[fti++] = prefix[ftj];
      I64 tcap = tname_len; if (fti+tcap > 254) tcap = 254-fti;
      for (ftj=0; ftj<tcap; ftj++) full_tname[fti++] = tname[ftj];
      full_tname[fti] = 0;

      if (ttype == OBJ_TREE) {
        U8 dmask[256];
        StrPrint(dmask, "%s*", check_path);
        CDirEntry *dde = FilesFind(dmask, 0);
        Bool still_dir = (dde != NULL);
        if (dde != NULL) DirTreeDel(dde);
        if (!still_dir) {
          U8 *sub_content_c = NULL; I64 sub_len_c = 0;
          I64 sub_off_rel_c;
          if (IndexLookup(idx_hashes, idx_offsets, idx_count, thash, &sub_off_rel_c)) {
            I64 sub_off_c = 16 + sub_off_rel_c;
            U64 sub_rec_len_c = GetU64LE(rbuf, sub_off_c);
            sub_content_c = rbuf + sub_off_c + 9;
            sub_len_c = sub_rec_len_c - 1;
          }
          U8 sub_prefix_c[256];
          I64 pic = 0, pjc;
          for (pjc=0; full_tname[pjc]; pjc++) sub_prefix_c[pic++] = full_tname[pjc];
          sub_prefix_c[pic++] = '/'; sub_prefix_c[pic] = 0;
          StatusTreeWalk(rbuf, idx_hashes, idx_offsets, idx_count,
                        check_path, sub_content_c, sub_len_c, sub_prefix_c);
        }
        // still_dir==TRUE: already handled by the new-tree pass above
        // (found && old_type==OBJ_TREE branch), skip to avoid a
        // duplicate report.
      } else {
        I64 check_size;
        U8 *check_buf = FileRead(check_path, &check_size);
        if (check_buf == NULL) {
          I64 dcap = fti; if (dcap > 254) dcap = 254;
          for (m=0; m<dcap; m++) del_names[del_count*256+m] = full_tname[m];
          del_names[del_count*256+dcap] = 0;
          for (m=0; m<64; m++) del_hashes[del_count*64+m] = thash[m];
          del_matched[del_count] = FALSE;
          del_count++;
        }
      }
    }
  }

  // Rename match, exact-hash then fuzzy - blob-only, one directory
  // level at a time, same as Diff.HC's own recursive version.
  I64 di, ni;
  for (di=0; di<del_count; di++) {
    for (ni=0; ni<new_count; ni++) {
      Bool hmatch = !new_matched[ni];
      I64 hi;
      if (hmatch) for (hi=0; hi<64; hi++) if (del_hashes[di*64+hi] != new_hashes[ni*64+hi]) hmatch = FALSE;
      if (hmatch) {
        CommPrint(1, "STATUS_RENAMED %s -> %s\n", del_names+di*256, new_names+ni*256);
        new_matched[ni] = TRUE;
        del_matched[di] = TRUE;
        ni = new_count;
      }
    }
  }
  for (di=0; di<del_count; di++) {
    if (!del_matched[di]) {
      I64 del_off_rel;
      if (IndexLookup(idx_hashes, idx_offsets, idx_count, del_hashes+di*64, &del_off_rel)) {
        I64 del_off = 16 + del_off_rel;
        U64 del_rec_len = GetU64LE(rbuf, del_off);
        U8 *del_content = rbuf + del_off + 9;
        I64 del_content_len = del_rec_len - 1;

        I64 best_ni = -1, best_sim = -1;
        for (ni=0; ni<new_count; ni++) {
          if (!new_matched[ni]) {
            I64 sim = FossilSimilarityPercent(del_content, del_content_len,
                                              new_contents+ni*512, new_content_lens[ni]);
            if (sim > best_sim) { best_sim = sim; best_ni = ni; }
          }
        }
        if (best_ni >= 0 && best_sim >= FOSSIL_RENAME_SIMILARITY_THRESHOLD) {
          CommPrint(1, "STATUS_RENAMED %s -> %s\n", del_names+di*256, new_names+best_ni*256);
          new_matched[best_ni] = TRUE;
          del_matched[di] = TRUE;
        }
      }
    }
  }

  for (ni=0; ni<new_count; ni++) {
    if (!new_matched[ni]) CommPrint(1, "STATUS_NEW %s\n", new_names+ni*256);
  }
  for (di=0; di<del_count; di++) {
    if (!del_matched[di]) CommPrint(1, "STATUS_DELETED %s\n", del_names+di*256);
  }

  Free(new_names);
  Free(new_hashes);
  Free(new_contents);
  Free(new_content_lens);
  Free(new_matched);
  Free(del_names);
  Free(del_hashes);
  Free(del_matched);
}

U0 HgitStatusTree(U8 *repo_path, U8 *dir_path)
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

  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 commit_off_rel;
  IndexLookup(idx_hashes, idx_offsets, idx_count, head_hash, &commit_off_rel);
  I64 commit_off = 16 + commit_off_rel;
  U8 *commit_content = rbuf + commit_off + 9;
  U8 *tree_hash = CommitTreeHash(commit_content);

  I64 tree_off_rel;
  IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &tree_off_rel);
  I64 tree_off = 16 + tree_off_rel;
  U64 tree_record_len = GetU64LE(rbuf, tree_off);
  U8 *tree_content = rbuf + tree_off + 9;
  I64 tree_content_len = tree_record_len - 1;

  U8 root_prefix[1]; root_prefix[0] = 0;
  StatusTreeWalk(rbuf, idx_hashes, idx_offsets, idx_count,
                dir_path, tree_content, tree_content_len, root_prefix);

  CommPrint(1, "STATUS_END\n");
  Free(idx_hashes);
  Free(idx_offsets);
}
// History.HC — `hgit history`: walk the parent chain from HEAD,
// printing each commit's timestamp and message.
//
// First real consumer of Index.HC's lookup for something other than a
// single dereference (probe 12's tree-entry case) - here it's walked
// repeatedly, once per commit, back through the parent chain. Only
// the first parent is ever followed (CommitParentHash(content, 0)) -
// this predates real merge commits (ADR 0011, probes 97-100), which
// now genuinely exist; a "first-parent-only" walk past a merge commit
// is a real, deliberate simplification for a plain sequential log
// (the same convention `git log --first-parent` names, not a bug),
// not the original "none have been created or tested" gap this
// comment used to describe. Confirmed against a real repo containing
// a real merge commit (probe 110, `experiments/110-history-graph-with-merge-commits/`):
// a merged-in path's own unique commits (only reachable via the
// merge's second parent) are honestly absent from this view - `hgit
// graph` is the command that surfaces them, nested under their own
// branch.
//
// Verified (experiments/19-hgit-history/) against the real two-commit
// repository `hgit offer` built in the previous session/probe - not a
// fresh fixture, an actual persisted repo from prior work, which this
// probe read back correctly across the QEMU reboot boundary.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC.

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

  // ADR 0007's same fix, applied here (experiments/62-index-buffer-sweep/):
  // idx_hashes/idx_offsets used to be fixed [64*64]/[64] stack arrays, a
  // hardcoded 64-object-in-the-whole-repo cap - MAlloc'd from `rcount`
  // (exact, from the .HGS header) instead, freed on every return path.
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
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
    if (!found) { CommPrint(1, "HISTORY_ERR broken_chain\n"); Free(idx_hashes); Free(idx_offsets); return; }
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
    if (obj_type != OBJ_COMMIT) { CommPrint(1, "HISTORY_ERR not_a_commit type=%d\n", obj_type); Free(idx_hashes); Free(idx_offsets); return; }

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
  Free(idx_hashes);
  Free(idx_offsets);
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

// Writes 16 lowercase hex chars + NUL (17 bytes total) into hex_out -
// same convention as HashToHex, but for a U64 (e.g. ADR 0004's entity
// IDs), which otherwise print as a negative number under a plain
// signed %d when the high bit is set (a real, hit-in-practice
// annoyance, not hypothetical - see experiments/49-entity-id/'s own
// README). Hex round-trips cleanly regardless of sign.
U0 U64ToHex(U64 v, U8 *hex_out)
{
  U8 *digits = "0123456789abcdef";
  I64 i;
  for (i=0; i<16; i++) {
    I64 shift = (15-i)*4;
    hex_out[i] = digits[(v >> shift) & 0xF];
  }
  hex_out[16] = 0;
}

// hex must be exactly 16 characters. Returns FALSE (out untouched) if
// any character isn't a valid hex digit.
Bool HexToU64(U8 *hex, U64 *out)
{
  U64 v = 0;
  I64 i;
  for (i=0; i<16; i++) {
    U8 d = HexDigit(hex[i]);
    if (d == 0xFF) return FALSE;
    v = (v << 4) | d;
  }
  *out = v;
  return TRUE;
}
// Check.HC — `hgit check`: verify every object in a repo's own
// archive really hashes to what it claims to, AND that every hash one
// object refers to (a commit's tree/parents/relation-target, a tree's
// own child entries) actually resolves to a real object in the same
// store. Design decisions written up retroactively in
// `docs/adr/0013-repository-integrity-check.md`.
//
// The original brief's command list included a "shrine check" - a
// repo-integrity verification command - that was never wired in as
// M1's command surface grew (`init`/`status`/`offer`/`history`/`see`,
// then M2/M3/M4's own additions). Probe 64 built the first slice
// (hash integrity only, a thin wrapper over M0's `ArchiveVerify`) and
// explicitly flagged referential integrity as "a real, separate check,
// out of scope for this first slice." This file now does that too,
// modeled on real `git fsck`'s own "missing object" check
// (git-scm.com/docs/git-fsck) - confirmed via its actual docs, not
// assumed: fsck's most common real failure mode is a commit/tree
// referencing a hash with no corresponding object in the store, found
// by walking the object graph and checking every reference resolves.
// This is a real, direct analogue of that check ("missing objects").
// The "dangling"/"unreachable" categories `git fsck` also reports were
// left out of that first slice, since they need a real reachability
// walk from every ref this project hadn't built yet - see below for
// that (and `docs/adr/0013-repository-integrity-check.md` for the
// full, three-slice design history).
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC, Object.HC,
// Commit.HC, Tree.HC, Index.HC, Meta.HC.
//
// (experiments/72-check-dangling-objects/): the "does no
// dangling/unreachable analysis" gap this file's own header comment
// used to flag is now closed too. `CheckMarkReachable` walks the real
// object graph - every declared path's HEAD (main plus every
// MetaPathDeclare'd name, via Meta.HC's `MetaPathListInto`), each
// commit's parents/tree/relation-target, each tree's own blob
// children - marking a parallel `reachable[]` array (indexed the same
// way `IndexBuild` filled `idx_hashes`/`idx_offsets`, via the new
// `IndexLookupPos`). Anything left unmarked after every path's history
// is walked is dangling: present in the store, unreachable from any
// real ref this repo has. Recursion stops the instant it re-enters an
// already-marked object, so shared history between multiple paths is
// only ever walked once.

// Marks `hash`'s object (and everything real it references) reachable
// in `reachable[]`. A no-op if `hash` isn't in the index at all (a
// broken reference - already reported by the referential-integrity
// pass above) or if it's already marked (stops re-walking shared
// history between paths, and rules out infinite recursion - a real
// content-addressed object graph can't contain a cycle without a hash
// collision).
U0 CheckMarkReachable(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                      Bool *reachable, U8 *hash)
{
  I64 ipos;
  if (!IndexLookupPos(idx_hashes, idx_count, hash, &ipos)) return;
  if (reachable[ipos]) return;
  reachable[ipos] = TRUE;

  I64 off = 16 + idx_offsets[ipos]; // idx_offsets are relative to
                                     // rbuf+16 - same convention every
                                     // other real command follows
                                     // (See.HC/Status.HC's own "Index
                                     // offsets are relative to..." note).
  U8 obj_type = rbuf[off+8];
  U8 *content = rbuf + off + 9;

  if (obj_type == OBJ_COMMIT) {
    U8 *tree_hash = CommitTreeHash(content);
    CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, tree_hash);
    U8 pcount = CommitParentCount(content);
    U8 pidx;
    for (pidx=0; pidx<pcount; pidx++) {
      U8 *parent_hash = CommitParentHash(content, pidx);
      CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, parent_hash);
    }
    U8 rel_tag = CommitRelationTag(content);
    if (rel_tag != REL_NONE) {
      U8 *rel_target = CommitRelationTarget(content);
      CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, rel_target);
    }
  } else if (obj_type == OBJ_TREE) {
    U32 tcount = GetU32LE(content, 0);
    I64 tpos = 4;
    U32 te;
    for (te=0; te<tcount; te++) {
      U8 tname_len = content[tpos]; tpos += 1;
      tpos += tname_len; // skip name
      tpos += 1; // skip child_type
      U8 *child_hash = content + tpos; tpos += 64;
      tpos += 8; // skip entity_id (ADR 0004)
      CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, child_hash);
    }
  }
  // OBJ_BLOB: no outgoing references, nothing further to mark.
}

U0 HgitCheck(U8 *repo_path)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "CHECK_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "CHECK_ERR bad_header\n"); return; }

  I64 total, ok;
  ArchiveVerify(rbuf+16, rsize-16, &total, &ok);

  if (total != rcount) {
    CommPrint(1, "CHECK_WARN object_count_mismatch header=%d scanned=%d\n",
              rcount, total);
  }
  // Probe 113 (experiments/113-check-format-version/): `format_version`
  // was read here (and everywhere else that opens a repo) but never
  // actually shown to a user by ANY real command - a real, previously-
  // unnoticed gap (found while investigating FORMAT.md's own
  // versioning-policy inconsistency) now that the version means
  // something worth checking.
  if (ok == total) {
    CommPrint(1, "CHECK_OK objects=%d format_version=%d\n", total, rver);
  } else {
    CommPrint(1, "CHECK_FAIL objects=%d ok=%d corrupt=%d format_version=%d\n", total, ok, total-ok, rver);
  }

  // Referential integrity pass: build the same hash->offset index
  // every real command uses (ADR 0007's own MAlloc'd sizing, not a
  // fixed cap), then walk every commit/tree object's own outgoing
  // references and confirm each one resolves.
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 broken_refs = 0;
  I64 pos = 16;
  while (pos < rsize) {
    U64 rec_len = GetU64LE(rbuf, pos);
    U8 obj_type = rbuf[pos+8];
    U8 *content = rbuf + pos + 9;

    if (obj_type == OBJ_COMMIT) {
      U8 *tree_hash = CommitTreeHash(content);
      I64 dummy_off;
      if (!IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &dummy_off)) {
        U8 hex[129];
        HashToHex(tree_hash, hex);
        CommPrint(1, "CHECK_BROKEN_REF commit_tree_missing %s\n", hex);
        broken_refs++;
      }
      U8 pcount = CommitParentCount(content);
      U8 pidx;
      for (pidx=0; pidx<pcount; pidx++) {
        U8 *parent_hash = CommitParentHash(content, pidx);
        I64 poff;
        if (!IndexLookup(idx_hashes, idx_offsets, idx_count, parent_hash, &poff)) {
          U8 phex[129];
          HashToHex(parent_hash, phex);
          CommPrint(1, "CHECK_BROKEN_REF commit_parent_missing %s\n", phex);
          broken_refs++;
        }
      }
      U8 rel_tag = CommitRelationTag(content);
      if (rel_tag != REL_NONE) {
        U8 *rel_target = CommitRelationTarget(content);
        I64 roff;
        if (!IndexLookup(idx_hashes, idx_offsets, idx_count, rel_target, &roff)) {
          U8 rhex[129];
          HashToHex(rel_target, rhex);
          CommPrint(1, "CHECK_BROKEN_REF relation_target_missing %s\n", rhex);
          broken_refs++;
        }
      }
    } else if (obj_type == OBJ_TREE) {
      U32 tcount = GetU32LE(content, 0);
      I64 tpos = 4;
      U32 te;
      for (te=0; te<tcount; te++) {
        U8 tname_len = content[tpos]; tpos += 1;
        tpos += tname_len; // skip name
        tpos += 1; // skip child_type - not needed to look it up
        U8 *child_hash = content + tpos; tpos += 64;
        tpos += 8; // skip entity_id (ADR 0004)
        I64 coff;
        if (!IndexLookup(idx_hashes, idx_offsets, idx_count, child_hash, &coff)) {
          U8 chex[129];
          HashToHex(child_hash, chex);
          CommPrint(1, "CHECK_BROKEN_REF tree_child_missing %s\n", chex);
          broken_refs++;
        }
      }
    }

    // Matches Archive.HC's own ArchiveVerify pattern exactly - plain
    // I64/U64 arithmetic, no explicit cast needed (already proven safe
    // there); avoids probe 68's newly-found postfix-cast pitfalls by
    // just not casting at all here.
    pos += 8 + rec_len + 64; // len field + data (incl. type tag) + hash
  }

  if (broken_refs == 0) {
    CommPrint(1, "CHECK_REFS_OK\n");
  } else {
    CommPrint(1, "CHECK_REFS_FAIL broken=%d\n", broken_refs);
  }

  // Dangling/unreachable pass: mark every object reachable from every
  // real path's HEAD, then report whatever's left unmarked.
  Bool *reachable = MAlloc(idx_count + 1);
  I64 zi;
  for (zi=0; zi<idx_count; zi++) reachable[zi] = FALSE;

  I64 path_count = MetaPathCount(repo_path);
  U8 *path_names = MAlloc((path_count+1)*META_MAX_PATH_NAME);
  I64 real_path_count;
  MetaPathListInto(repo_path, path_names, &real_path_count);

  I64 pi2; // NOT "pi" - reserved F64 constant, probe 41's own gotcha
  for (pi2=0; pi2<real_path_count; pi2++) {
    U8 *pname = path_names + pi2*META_MAX_PATH_NAME;
    U8 phead_hash[64];
    if (MetaReadHead(repo_path, pname, phead_hash)) {
      CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, phead_hash);
    }
  }

  // Coalesce duplicates: `Object.HC`'s own `ObjectPut` is a plain
  // append with no content-hash dedup, so if the same content is
  // offered more than once over a repo's life (found in practice on
  // `P65Repo.hgs`, a long-lived repo this project has reoffered the
  // same "v1"/"v2" content into across many probes), the exact same
  // hash can occupy several different archive positions.
  // `CheckMarkReachable`'s `IndexLookupPos` scan only ever marks
  // whichever position it finds *first* as reachable - every OTHER
  // position holding that identical hash is content-identical (same
  // hash = same content) and therefore equally reachable, just never
  // marked. One linear coalescing pass fixes this: no fixed point
  // needed, since a duplicate's own outgoing references are
  // byte-identical to the original's and already resolved by the
  // original's own walk.
  I64 ca, cb;
  for (ca=0; ca<idx_count; ca++) {
    if (!reachable[ca]) {
      for (cb=0; cb<idx_count; cb++) {
        Bool dup_of_reachable = reachable[cb];
        I64 hb;
        if (dup_of_reachable) {
          for (hb=0; hb<64; hb++) {
            if (idx_hashes[ca*64+hb] != idx_hashes[cb*64+hb]) dup_of_reachable = FALSE;
          }
        }
        if (dup_of_reachable) { reachable[ca] = TRUE; break; }
      }
    }
  }

  I64 dangling = 0;
  for (zi=0; zi<idx_count; zi++) {
    if (!reachable[zi]) {
      dangling++;
      I64 doff = 16 + idx_offsets[zi];
      U8 dtype = rbuf[doff+8];
      U8 *kind = "blob";
      if (dtype == OBJ_COMMIT) kind = "commit";
      else if (dtype == OBJ_TREE) kind = "tree";
      U8 dhex[129];
      HashToHex(idx_hashes + zi*64, dhex);
      CommPrint(1, "CHECK_DANGLING %s %s\n", kind, dhex);
    }
  }
  if (dangling == 0) CommPrint(1, "CHECK_DANGLING_NONE\n");
  else CommPrint(1, "CHECK_DANGLING_COUNT %d\n", dangling);

  Free(idx_hashes);
  Free(idx_offsets);
  Free(reachable);
  Free(path_names);
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

  // ADR 0007's same fix, applied here (experiments/62-index-buffer-sweep/):
  // idx_hashes/idx_offsets used to be fixed [64*64]/[64] stack arrays, a
  // hardcoded 64-object-in-the-whole-repo cap - MAlloc'd from `rcount`
  // (exact, from the .HGS header) instead, freed before this function
  // returns (only one exit path here, after the loop's own `break`s).
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  U8 cur_hash[64];
  I64 k;
  for (k=0; k<64; k++) cur_hash[k] = head_hash[k];
  Bool has_cur = TRUE;
  Bool truncated = FALSE;

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

    // Real bug found and fixed (experiments/67-historydoc-buffer-guard/):
    // `doc[8192]` was unbounded against a repo's real commit count -
    // reproduced a genuine kernel GPF against a real ~300-commit repo
    // (RIP inside &StrNew, stack corruption from this buffer's own
    // overflow manifesting elsewhere, same pattern as probe 60's own
    // crash). Guarded the same way `HgitReconcileOverview` already is
    // (probe 59): stop cleanly with a margin before the buffer's own
    // capacity, instead of overflowing it.
    U32 mlen = CommitMessageLen(content);
    if (dlen + mlen > 8192 - 256) {
      truncated = TRUE;
      break;
    }

    U8 pcount = CommitParentCount(content);
    U64 ts = CommitTimestamp(content);
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

  if (truncated) {
    U8 *m = "(truncated - too much history for one document)$CR$";
    I64 mi;
    for (mi=0; m[mi]; mi++) doc[dlen++] = m[mi];
  }

  FileWrite(doc_path, doc, dlen);
  Free(idx_hashes);
  Free(idx_offsets);
}
// ReconcileDoc.HC — `hgit reconciledoc`/`hgit reconcileoverview`: the
// real DolDoc reconciliation views (M4).
//
// Probe 54 (`experiments/54-doldoc-widgets/`) confirmed `$LK$` renders
// as a real clickable/underlined link from HolyC-generated output.
// Probe 57 (`experiments/57-tree-widget/`) then resolved `$TR$`'s real
// syntax from actual TempleOS demo source
// (`C:/Demo/DolDoc/TreeDemo.HC`): a single self-contained
// `$TR,"<label>"$` command (no closing tag), with nesting done via a
// separate `$ID,+2$ ... $ID,-2$` bracket around the children. Probe 58
// put both to use for one commit at a time (`HgitReconcileDoc`).
//
// Probe 59 (`experiments/59-reconcile-overview/`) factors the
// per-commit rendering out into `ReconcileEmitCommit` (defined first -
// HolyC has no forward declarations, a real recurring gotcha in this
// project, see docs/research/01-templeos-holyc.md) so a second real
// command, `HgitReconcileOverview`, can walk a repo's *entire* history
// (same parent-chain walk `HistoryDoc.HC` already does) and emit one
// real tree node per commit that actually carries a relation, skipping
// ordinary commits - a real multi-commit reconciliation view, not just
// a single-commit lookup the caller has to already know the hash for.
//
// Scoped honestly, matching probe 54's own findings: this does NOT
// test or implement following the link (that needs a human click or a
// callback dispatcher neither built nor verified yet - `Ed()` itself
// was found to block the daemon's command loop, so driving a click
// through the same automated push channel isn't possible without a
// human at the console). What's verified is that the link and the
// tree nodes are really there in both the raw bytes and the rendered
// view - see probe 55's, probe 58's, and probe 59's own READMEs for
// exactly what was and wasn't checked.
//
// No function-like macros used here (untested territory in this
// codebase - every other .HC file only ever uses #define for plain
// constants, never a macro body) - each literal is appended with its
// own explicit loop, same style as HistoryDoc.HC.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC, Hex.HC, Paths.HC (CurrentHeadRead, for HgitReconcileOverview).

// Appends one commit's short hash/message, and (if it carries an ADR
// 0005/0006 relation) a real collapsible $TR$ tree node for that
// relation, to `doc`/`*dlen`. `content` is the commit's own decoded
// object content (caller already resolved `cur_hash` via the index -
// shared here rather than re-looked-up, since HgitReconcileOverview's
// caller already has it mid-walk).
//
// Returns TRUE if this commit had a relation (so HgitReconcileOverview
// can count how many nodes it actually emitted).
Bool ReconcileEmitCommit(U8 *doc, I64 *dlen, U8 *rbuf,
                          U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                          U8 *cur_hash, U8 *content)
{
  I64 fi, hi, k;
  U8 hex[129];
  HashToHex(cur_hash, hex);
  U8 *fg_hash = "$FG,2$";
  for (fi=0; fg_hash[fi]; fi++) doc[*dlen+fi] = fg_hash[fi]; *dlen += fi;
  for (hi=0; hi<12; hi++) doc[(*dlen)++] = hex[hi];
  U8 *fg_end = "$FG$ ";
  for (fi=0; fg_end[fi]; fi++) doc[*dlen+fi] = fg_end[fi]; *dlen += fi;

  U32 mlen = CommitMessageLen(content);
  U8 *msg = CommitMessage(content);
  for (k=0; k<mlen; k++) doc[(*dlen)++] = msg[k];
  U8 *cr2 = "$CR$$CR$";
  for (fi=0; cr2[fi]; fi++) doc[*dlen+fi] = cr2[fi]; *dlen += fi;

  U8 rel_tag = CommitRelationTag(content);
  if (rel_tag == REL_NONE) {
    return FALSE;
  }

  U8 *rel_name;
  if (rel_tag == REL_CONTINUES) rel_name = "CONTINUES";
  else if (rel_tag == REL_CORRECTS) rel_name = "CORRECTS";
  else if (rel_tag == REL_REVERTS) rel_name = "REVERTS";
  else if (rel_tag == REL_RECONCILES) rel_name = "RECONCILES";
  else rel_name = "UNKNOWN";

  U8 *rel_target = CommitRelationTarget(content);
  U8 rel_hex[129];
  HashToHex(rel_target, rel_hex);

  // One real collapsible tree node (probe 57) for the relation itself
  // - $TR$'s label is a plain quoted string, so the link and any other
  // $..$ commands stay OUTSIDE the label, as this node's indented
  // ($ID,+2$/$ID,-2$) children instead of embedded inside the quotes.
  U8 *tr_open = "$TR,\"relation: ";
  for (fi=0; tr_open[fi]; fi++) doc[*dlen+fi] = tr_open[fi]; *dlen += fi;
  for (fi=0; rel_name[fi]; fi++) doc[(*dlen)++] = rel_name[fi];
  U8 *tr_close = "\"$$CR$$ID,+2$";
  for (fi=0; tr_close[fi]; fi++) doc[*dlen+fi] = tr_close[fi]; *dlen += fi;

  U8 *tgt_lbl = "target: $LK,\"";
  for (fi=0; tgt_lbl[fi]; fi++) doc[*dlen+fi] = tgt_lbl[fi]; *dlen += fi;
  for (hi=0; hi<128; hi++) doc[(*dlen)++] = rel_hex[hi];
  U8 *lkmid = "\"$";
  for (fi=0; lkmid[fi]; fi++) doc[*dlen+fi] = lkmid[fi]; *dlen += fi;
  for (hi=0; hi<12; hi++) doc[(*dlen)++] = rel_hex[hi];
  U8 *lkend = "$LK$$CR$";
  for (fi=0; lkend[fi]; fi++) doc[*dlen+fi] = lkend[fi]; *dlen += fi;

  // Show the target commit's own message too, if it's in this same
  // archive (it always will be for a same-repo relation, per ADR
  // 0005's own design).
  I64 toff_rel;
  if (IndexLookup(idx_hashes, idx_offsets, idx_count, rel_target, &toff_rel)) {
    I64 toff = 16 + toff_rel;
    if (rbuf[toff+8] == OBJ_COMMIT) {
      U8 *tcontent = rbuf + toff + 9;
      U32 tmlen = CommitMessageLen(tcontent);
      U8 *tmsg = CommitMessage(tcontent);
      U8 *tlbl = "target message: ";
      for (fi=0; tlbl[fi]; fi++) doc[*dlen+fi] = tlbl[fi]; *dlen += fi;
      for (k=0; k<tmlen; k++) doc[(*dlen)++] = tmsg[k];
      U8 *cr3 = "$CR$";
      for (fi=0; cr3[fi]; fi++) doc[*dlen+fi] = cr3[fi]; *dlen += fi;
    }
  }

  U64 rel_entity_id = CommitRelationEntityId(content);
  if (rel_entity_id != 0) {
    U8 ehex[17];
    U64ToHex(rel_entity_id, ehex);
    U8 *elbl = "scoped to entity: ";
    for (fi=0; elbl[fi]; fi++) doc[*dlen+fi] = elbl[fi]; *dlen += fi;
    for (hi=0; hi<16; hi++) doc[(*dlen)++] = ehex[hi];
    U8 *cr4 = "$CR$";
    for (fi=0; cr4[fi]; fi++) doc[*dlen+fi] = cr4[fi]; *dlen += fi;
  }

  U8 *id_close = "$ID,-2$";
  for (fi=0; id_close[fi]; fi++) doc[*dlen+fi] = id_close[fi]; *dlen += fi;

  return TRUE;
}

U0 HgitReconcileDoc(U8 *repo_path, U8 *target_hash, U8 *doc_path)
{
  U8 doc[8192];
  I64 dlen = 0;
  I64 fi;
  U8 *title = "$FG,5$hgit reconciliation$FG$$CR$$CR$";
  for (fi=0; title[fi]; fi++) doc[dlen++] = title[fi];

  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) {
    U8 *m1 = "(not a repository)$CR$";
    for (fi=0; m1[fi]; fi++) doc[dlen++] = m1[fi];
    FileWrite(doc_path, doc, dlen);
    return;
  }
  U16 rver; U64 rcount;
  if (!HgsReadHeader(rbuf, &rver, &rcount)) {
    U8 *m2 = "(bad header)$CR$";
    for (fi=0; m2[fi]; fi++) doc[dlen++] = m2[fi];
    FileWrite(doc_path, doc, dlen);
    return;
  }

  // ADR 0007's same fix, applied here (experiments/62-index-buffer-sweep/):
  // idx_hashes/idx_offsets used to be fixed [64*64]/[64] stack arrays, a
  // hardcoded 64-object-in-the-whole-repo cap - MAlloc'd from `rcount`
  // (exact, from the .HGS header) instead, freed on every return path.
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, target_hash, &off_rel)) {
    U8 *m3 = "(commit not found)$CR$";
    for (fi=0; m3[fi]; fi++) doc[dlen++] = m3[fi];
    FileWrite(doc_path, doc, dlen);
    Free(idx_hashes);
    Free(idx_offsets);
    return;
  }
  I64 off = 16 + off_rel;
  U8 obj_type = rbuf[off+8];
  if (obj_type != OBJ_COMMIT) {
    U8 *m4 = "(not a commit)$CR$";
    for (fi=0; m4[fi]; fi++) doc[dlen++] = m4[fi];
    FileWrite(doc_path, doc, dlen);
    Free(idx_hashes);
    Free(idx_offsets);
    return;
  }
  U8 *content = rbuf + off + 9;

  Bool had_rel = ReconcileEmitCommit(doc, &dlen, rbuf, idx_hashes, idx_offsets,
                                      idx_count, target_hash, content);
  if (!had_rel) {
    U8 *m5 = "(no relation on this commit)$CR$";
    for (fi=0; m5[fi]; fi++) doc[dlen++] = m5[fi];
  }

  FileWrite(doc_path, doc, dlen);
  Free(idx_hashes);
  Free(idx_offsets);
}

// `hgit reconcileoverview <repo> <dest.DD>` - walks the whole real
// parent chain from HEAD (same walk `HistoryDoc.HC` does), emitting a
// real $TR$ tree node for every commit that carries a relation and
// skipping every commit that doesn't (a plain offer isn't
// reconciliation-relevant, so it's left out of this view entirely
// rather than cluttering it - `hgit historydoc` already covers the
// full plain history).
U0 HgitReconcileOverview(U8 *repo_path, U8 *doc_path)
{
  U8 doc[8192];
  I64 dlen = 0;
  I64 fi;
  U8 *title = "$FG,5$hgit reconciliation overview$FG$$CR$$CR$";
  for (fi=0; title[fi]; fi++) doc[dlen++] = title[fi];

  U8 head_hash[64];
  if (!CurrentHeadRead(repo_path, head_hash)) {
    U8 *m1 = "(no offerings yet)$CR$";
    for (fi=0; m1[fi]; fi++) doc[dlen++] = m1[fi];
    FileWrite(doc_path, doc, dlen);
    return;
  }

  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  U16 rver; U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  // ADR 0007's same fix, applied here (experiments/62-index-buffer-sweep/):
  // idx_hashes/idx_offsets used to be fixed [64*64]/[64] stack arrays, a
  // hardcoded 64-object-in-the-whole-repo cap - MAlloc'd from `rcount`
  // (exact, from the .HGS header) instead, freed before this function's
  // one exit path (after the loop's own `break`s).
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  U8 cur_hash[64];
  I64 zi;
  for (zi=0; zi<64; zi++) cur_hash[zi] = head_hash[zi];
  Bool has_cur = TRUE;
  I64 rel_count = 0;
  Bool truncated = FALSE;

  while (has_cur) {
    I64 off_rel;
    Bool found = IndexLookup(idx_hashes, idx_offsets, idx_count, cur_hash, &off_rel);
    if (!found) break;
    I64 off = 16 + off_rel;
    U8 obj_type = rbuf[off+8];
    if (obj_type != OBJ_COMMIT) break;
    U8 *content = rbuf + off + 9;

    // Same class of fixed-buffer risk probe 56 found and guarded in
    // Offer.HC: `doc[8192]` is unbounded against a repo's real commit
    // count/message sizes. A repo with many relation-carrying commits
    // (or long messages) could overflow it. Guarded the same way -
    // stop cleanly and say so, rather than silently overflowing.
    // 1024 bytes of headroom is a heuristic margin (one relation node
    // plus a commit's own header rarely exceeds it), not a proven
    // bound - same honest caveat as every other fixed-size buffer in
    // this codebase.
    if (dlen > 8192 - 1024) {
      truncated = TRUE;
      break;
    }

    I64 mark = dlen; // this view only shows relation-carrying commits;
                      // ReconcileEmitCommit always writes the commit's
                      // own hash/message header first, so a
                      // no-relation commit's header is rolled back by
                      // resetting dlen to this mark rather than
                      // teaching ReconcileEmitCommit to peek ahead
                      // before writing anything.
    Bool had_rel = ReconcileEmitCommit(doc, &dlen, rbuf, idx_hashes, idx_offsets,
                                        idx_count, cur_hash, content);
    if (had_rel) rel_count++;
    else dlen = mark;

    U8 pcount = CommitParentCount(content);
    if (pcount > 0) {
      U8 *parent = CommitParentHash(content, 0);
      I64 pj;
      for (pj=0; pj<64; pj++) cur_hash[pj] = parent[pj];
      has_cur = TRUE;
    } else {
      has_cur = FALSE;
    }
  }

  if (rel_count == 0) {
    U8 *m2 = "(no relations found in this repo's history)$CR$";
    for (fi=0; m2[fi]; fi++) doc[dlen++] = m2[fi];
  }
  if (truncated) {
    U8 *m3 = "(truncated - too many relations/commits for one document)$CR$";
    for (fi=0; m3[fi]; fi++) doc[dlen++] = m3[fi];
  }

  FileWrite(doc_path, doc, dlen);
  Free(idx_hashes);
  Free(idx_offsets);
}
// Graph.HC — `hgit graph`: a real DolDoc tree view of a repo's ENTIRE
// commit history across every declared path, not just one path's own
// linear chain (`historydoc`) or relation-carrying commits only
// (`reconcileoverview`). "main"'s own chain is the trunk; every OTHER
// declared path attaches as its own nested branch at the exact commit
// it forked from (`path new` copies the current path's HEAD at
// creation time - Paths.HC's own `PathNew` - so a real, findable fork
// point always exists on a direct ancestor path) - a real, rendered
// analogue of `git log --graph --all`, scoped to this project's own
// actual ref model (named paths, each rendered as its own branch
// group by walking backward until a commit already in main's chain is
// hit - real multi-parent commits DO exist now, ADR 0011, confirmed
// not to crash or corrupt anything against a real merge-containing
// repo, probe 110, `experiments/110-history-graph-with-merge-commits/`
// - but this walk still only ever follows a commit's FIRST parent,
// same simplification `History.HC`'s own note describes, so a merge
// commit itself renders as one plain line on its own branch's trunk,
// not as a real, connected DAG rejoin between two group nodes).
//
// ONE `$TR$` widget per BRANCH (main's own trunk, and each other
// path), not one per commit - a real redesign (probe 81's own
// original per-commit nesting, see experiments/81-hgit-graph/'s own
// follow-up research). Reading TempleOS's own real DolDoc source
// (D:/Adam/DolDoc/DocRun.HC.Z) confirmed expanding a `$TR$` node
// REPLACES its own label with its child content, cascading through
// every nested level - fine for one level, but a per-commit design
// means fully expanding a real history renders as a string of
// "-]-]-] <deepest commit only>" with every ancestor's own label
// gone, not a readable indented list. Wrapping a whole branch's
// commits as ONE collapsible group, with each commit as a plain
// (non-widget) line inside it, avoids this entirely: only one label
// ever gets "replaced" per branch (the group's own summary line,
// swapped for its real content on expand - the same trade-off any
// collapsible section makes), and the commits themselves stay
// visible and readable once that group is open.
//
// Scoped honestly: a branch's fork point is found by walking backward
// from its HEAD until a commit already in MAIN's own chain is hit -
// if a path was itself created FROM another non-main path (a branch
// of a branch), and that intermediate path's own unique commits never
// reach main directly, this renders the grandchild path as its own
// second top-level group instead of nesting it under its true
// immediate parent path. A real, documented simplification for this
// version, not a silent wrong answer - the path's own full history is
// still shown completely, just not nested under the exact right
// ancestor.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC, Hex.HC, Meta.HC (MetaPathCount/MetaPathListInto/
// MetaReadHead).

U0 GraphAppendStr(U8 *doc, I64 *dlen, U8 *s)
{
  I64 gi;
  for (gi=0; s[gi]; gi++) doc[*dlen+gi] = s[gi];
  *dlen += gi;
}

// Opens one BRANCH's own collapsible $TR$ group node - a real commit
// count in the label (not a guessed name), so collapsed state alone
// already tells you how much is inside. Caller closes with $ID,-2$
// once every commit line (and any nested branch groups) are written.
U0 GraphOpenBranchNode(U8 *doc, I64 *dlen, U8 *label_prefix, I64 commit_count)
{
  GraphAppendStr(doc, dlen, "$TR,\"");
  GraphAppendStr(doc, dlen, label_prefix);
  U8 numbuf[24];
  I64 ni = 0, nv = commit_count;
  if (nv == 0) numbuf[ni++] = '0';
  while (nv > 0) { numbuf[ni++] = '0' + nv%10; nv /= 10; }
  I64 nj;
  for (nj=ni-1; nj>=0; nj--) doc[(*dlen)++] = numbuf[nj];
  GraphAppendStr(doc, dlen, " commits\"$$ID,+2$");
}

// Appends one commit as a plain (non-widget) line - real hash prefix
// and real message, no collapsibility of its own. This is the whole
// point of the redesign: a commit is just readable text, never a
// vanishing-on-expand label.
U0 GraphAppendCommitLine(U8 *doc, I64 *dlen, U8 *hash, U8 *content)
{
  U8 hex[129];
  HashToHex(hash, hex);
  I64 hi;
  for (hi=0; hi<10; hi++) doc[(*dlen)++] = hex[hi];
  GraphAppendStr(doc, dlen, " ");
  U32 mlen = CommitMessageLen(content);
  U8 *msg = CommitMessage(content);
  I64 mi;
  for (mi=0; mi<mlen; mi++) doc[(*dlen)++] = msg[mi];
  GraphAppendStr(doc, dlen, "$CR$");
}

U0 HgitGraph(U8 *repo_path, U8 *doc_path)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) {
    U8 doc0[64];
    I64 dlen0 = 0;
    GraphAppendStr(doc0, &dlen0, "(no repository)$CR$");
    FileWrite(doc_path, doc0, dlen0);
    return;
  }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok || rcount == 0) {
    U8 doc1[64];
    I64 dlen1 = 0;
    GraphAppendStr(doc1, &dlen1, "(no offerings yet)$CR$");
    FileWrite(doc_path, doc1, dlen1);
    return;
  }

  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 path_count = MetaPathCount(repo_path);
  U8 *path_names = MAlloc((path_count+1)*META_MAX_PATH_NAME);
  I64 real_path_count;
  MetaPathListInto(repo_path, path_names, &real_path_count);

  // doc[]: sized generously from the repo's real object count (same
  // "MAlloc from a real count, no arbitrary fixed cap" discipline as
  // every dynamic buffer since ADR 0007) - 300 bytes/commit covers a
  // hash + typical message + this widget's own markup overhead with
  // real headroom. Not a proven bound for an unusually long individual
  // commit message - same honest caveat every other heuristic-sized
  // buffer in this codebase carries (see "Not yet done" in this
  // probe's own README).
  U8 *doc = MAlloc(rcount*300 + 4096);
  I64 dlen = 0;
  GraphAppendStr(doc, &dlen, "$FG,5$hgit history graph$FG$$CR$$CR$");

  U8 main_head[64];
  Bool has_main = MetaReadHead(repo_path, "main", main_head);
  if (!has_main) {
    GraphAppendStr(doc, &dlen, "(no offerings yet)$CR$");
    FileWrite(doc_path, doc, dlen);
    Free(idx_hashes); Free(idx_offsets); Free(path_names); Free(doc);
    return;
  }

  // Walk main's own chain, HEAD..root order first (easiest direction
  // to follow parent pointers), then reverse in place so index 0 is
  // the root and rendering can walk root-to-tip.
  U8 *main_chain = MAlloc(rcount*64 + 64);
  I64 main_count = 0;
  U8 mcur[64];
  I64 mzi;
  for (mzi=0; mzi<64; mzi++) mcur[mzi] = main_head[mzi];
  Bool has_mcur = TRUE;
  while (has_mcur) {
    I64 moff_rel;
    if (!IndexLookup(idx_hashes, idx_offsets, idx_count, mcur, &moff_rel)) {
      has_mcur = FALSE;
    } else {
      I64 moff = 16 + moff_rel;
      if (rbuf[moff+8] != OBJ_COMMIT) {
        has_mcur = FALSE;
      } else {
        U8 *mcontent = rbuf + moff + 9;
        for (mzi=0; mzi<64; mzi++) main_chain[main_count*64+mzi] = mcur[mzi];
        main_count++;
        U8 mpcount = CommitParentCount(mcontent);
        if (mpcount > 0) {
          U8 *mparent = CommitParentHash(mcontent, 0);
          for (mzi=0; mzi<64; mzi++) mcur[mzi] = mparent[mzi];
          has_mcur = TRUE;
        } else {
          has_mcur = FALSE;
        }
      }
    }
  }
  I64 mlo = 0, mhi = main_count-1;
  while (mlo < mhi) {
    U8 mtmp[64];
    I64 mtzi;
    for (mtzi=0; mtzi<64; mtzi++) mtmp[mtzi] = main_chain[mlo*64+mtzi];
    for (mtzi=0; mtzi<64; mtzi++) main_chain[mlo*64+mtzi] = main_chain[mhi*64+mtzi];
    for (mtzi=0; mtzi<64; mtzi++) main_chain[mhi*64+mtzi] = mtmp[mtzi];
    mlo++; mhi--;
  }

  // For every OTHER declared path, walk its own chain backward from
  // its own HEAD until a commit already in main_chain is hit (its
  // fork point), storing its own unique commits (oldest-of-branch
  // first, matching main_chain's own convention) and that fork index
  // for the render pass below. All paths' own branch data is
  // computed up front (not rendered immediately) since rendering
  // happens ordered by main_chain position, not by path list order.
  I64 *fork_idx = MAlloc(real_path_count*8 + 8);
  I64 *branch_count = MAlloc(real_path_count*8 + 8);
  U8 *branch_chains = MAlloc(real_path_count*rcount*64 + 64);

  I64 pn;
  for (pn=0; pn<real_path_count; pn++) {
    U8 *pname = path_names + pn*META_MAX_PATH_NAME;
    Bool is_main = (StrCmp(pname, "main") == 0);
    fork_idx[pn] = -1;
    branch_count[pn] = 0;
    if (!is_main) {
      U8 phead[64];
      Bool has_phead = MetaReadHead(repo_path, pname, phead);
      if (has_phead) {
        U8 bcur[64];
        I64 bzi;
        for (bzi=0; bzi<64; bzi++) bcur[bzi] = phead[bzi];
        Bool has_bcur = TRUE;
        I64 bcount = 0;
        while (has_bcur) {
          I64 mi2, found_at = -1;
          for (mi2=0; mi2<main_count; mi2++) {
            Bool same = TRUE;
            I64 hb;
            for (hb=0; hb<64; hb++) if (main_chain[mi2*64+hb] != bcur[hb]) same = FALSE;
            if (same) found_at = mi2;
          }
          if (found_at >= 0) {
            fork_idx[pn] = found_at;
            has_bcur = FALSE;
          } else {
            I64 boff_rel;
            if (!IndexLookup(idx_hashes, idx_offsets, idx_count, bcur, &boff_rel)) {
              has_bcur = FALSE;
            } else {
              I64 boff = 16 + boff_rel;
              if (rbuf[boff+8] != OBJ_COMMIT) {
                has_bcur = FALSE;
              } else {
                U8 *bcontent = rbuf + boff + 9;
                for (bzi=0; bzi<64; bzi++)
                  branch_chains[(pn*rcount+bcount)*64+bzi] = bcur[bzi];
                bcount++;
                U8 bpcount = CommitParentCount(bcontent);
                if (bpcount > 0) {
                  U8 *bparent = CommitParentHash(bcontent, 0);
                  for (bzi=0; bzi<64; bzi++) bcur[bzi] = bparent[bzi];
                  has_bcur = TRUE;
                } else {
                  has_bcur = FALSE;
                }
              }
            }
          }
        }
        // Reverse this path's own segment so index 0 is the oldest
        // commit unique to this branch (right after the fork point).
        I64 blo = 0, bhi = bcount-1;
        while (blo < bhi) {
          U8 btmp[64];
          I64 btzi;
          for (btzi=0; btzi<64; btzi++) btmp[btzi] = branch_chains[(pn*rcount+blo)*64+btzi];
          for (btzi=0; btzi<64; btzi++) branch_chains[(pn*rcount+blo)*64+btzi] = branch_chains[(pn*rcount+bhi)*64+btzi];
          for (btzi=0; btzi<64; btzi++) branch_chains[(pn*rcount+bhi)*64+btzi] = btmp[btzi];
          blo++; bhi--;
        }
        branch_count[pn] = bcount;
      }
    }
  }

  // Render: ONE collapsible group for the whole main trunk, its own
  // commits as plain lines inside. Immediately after the trunk commit
  // a path forked from, open THAT path's own nested group (its own
  // plain commit lines), close it, then continue with main's own next
  // commit - so at most one extra level of $TR$ nesting ever exists
  // (a branch group inside the trunk group), never one per commit.
  GraphOpenBranchNode(doc, &dlen, "main, ", main_count);
  I64 ci;
  for (ci=0; ci<main_count; ci++) {
    I64 coff_rel;
    IndexLookup(idx_hashes, idx_offsets, idx_count, main_chain+ci*64, &coff_rel);
    I64 coff = 16 + coff_rel;
    U8 *ccontent = rbuf + coff + 9;
    GraphAppendCommitLine(doc, &dlen, main_chain+ci*64, ccontent);

    I64 apn;
    for (apn=0; apn<real_path_count; apn++) {
      if (fork_idx[apn] == ci) {
        U8 *apname = path_names + apn*META_MAX_PATH_NAME;
        U8 lbl[META_MAX_PATH_NAME+4];
        I64 li = 0;
        lbl[li++] = '[';
        I64 lj;
        for (lj=0; apname[lj]; lj++) lbl[li++] = apname[lj];
        lbl[li++] = ']'; lbl[li++] = ' '; lbl[li] = 0;
        GraphOpenBranchNode(doc, &dlen, lbl, branch_count[apn]);
        I64 bi;
        for (bi=0; bi<branch_count[apn]; bi++) {
          U8 *bhash = branch_chains + (apn*rcount+bi)*64;
          I64 aoff_rel;
          IndexLookup(idx_hashes, idx_offsets, idx_count, bhash, &aoff_rel);
          I64 aoff = 16 + aoff_rel;
          U8 *acontent = rbuf + aoff + 9;
          GraphAppendCommitLine(doc, &dlen, bhash, acontent);
        }
        GraphAppendStr(doc, &dlen, "$ID,-2$");
      }
    }
  }
  GraphAppendStr(doc, &dlen, "$ID,-2$");

  FileWrite(doc_path, doc, dlen);

  Free(idx_hashes);
  Free(idx_offsets);
  Free(path_names);
  Free(main_chain);
  Free(fork_idx);
  Free(branch_count);
  Free(branch_chains);
  Free(doc);
}
// See.HC — `hgit see <offering>`: show one commit's full detail -
// message, timestamp, parent count and hashes (probe 112 - a real
// merge commit's own SECOND parent was previously invisible here,
// only the count was shown), and its tree's entries.
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
// Index.HC, Hex.HC (HashToHex for a relation target; U64ToHex for
// entity IDs, printed in hex rather than plain %d since a U64 with the
// high bit set otherwise prints as a negative number).
//
// Tree-entry parsing updated for ADR 0004's 8-byte entity ID field
// (experiments/49-entity-id/) - this file walks tree entries manually
// (not via Tree.HC's TreeFindEntry) so it needed its own offset fix.
//
// Also prints ADR 0005/0006's relation tag/target/entity, if the
// commit has one (experiments/51-relation-commands/,
// experiments/53-entity-scoped-relations/).
//
// Recurses into nested trees (ADR 0010, experiments/93-see-nested-
// trees/) - a real, user-visible gap `hgit offertree` left open:
// before this, `see` only ever printed one flat level of entries, so
// a subdirectory's own contents were invisible short of a separate
// command. `SeePrintTreeEntries` is generic per-object-type (same
// pattern `CheckMarkReachable` in Check.HC already established for
// this project) - an `OBJ_TREE` child is looked up and recursed into,
// indented one level deeper, with no depth limit.

// Recursively prints one tree's own entries, then recurses into any
// `OBJ_TREE` child at `depth+1` indentation. A missing child object
// prints a real, honest marker instead of silently stopping or
// crashing - the same "don't hide a broken reference" stance
// Check.HC's own referential-integrity pass takes.
U0 SeePrintTreeEntries(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                       U8 *tree_content, I64 depth)
{
  U32 tcount = GetU32LE(tree_content, 0);
  I64 tpos = 4;
  U32 te;
  I64 i, d;
  for (te=0; te<tcount; te++) {
    U8 nlen = tree_content[tpos]; tpos += 1;
    U8 *name = tree_content + tpos; tpos += nlen;
    U8 ttype = tree_content[tpos]; tpos += 1;
    U8 *child_hash = tree_content + tpos; tpos += 64;
    U64 entity_id = GetU64LE(tree_content, tpos); tpos += 8; // ADR 0004
    U8 entity_hex[17];
    U64ToHex(entity_id, entity_hex);

    for (d=0; d<depth; d++) CommPrint(1, "  ");
    CommPrint(1, "  entry type=%d id=%s name=", ttype, entity_hex);
    for (i=0; i<nlen; i++) CommPrint(1, "%c", name[i]);
    CommPrint(1, "\n");

    if (ttype == OBJ_TREE) {
      I64 child_off_rel;
      Bool child_found = IndexLookup(idx_hashes, idx_offsets, idx_count,
                                      child_hash, &child_off_rel);
      if (child_found) {
        I64 child_off = 16 + child_off_rel;
        U8 *child_content = rbuf + child_off + 9;
        SeePrintTreeEntries(rbuf, idx_hashes, idx_offsets, idx_count,
                            child_content, depth+1);
      } else {
        for (d=0; d<depth+1; d++) CommPrint(1, "  ");
        CommPrint(1, "  (missing nested tree object)\n");
      }
    }
  }
}

U0 HgitSee(U8 *repo_path, U8 *target_hash)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "SEE_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "SEE_ERR bad_header\n"); return; }

  // ADR 0007's same fix, applied here (experiments/62-index-buffer-sweep/):
  // idx_hashes/idx_offsets used to be fixed [64*64]/[64] stack arrays, a
  // hardcoded 64-object-in-the-whole-repo cap - MAlloc'd from `rcount`
  // (exact, from the .HGS header) instead, freed on every return path.
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 off_rel;
  Bool found = IndexLookup(idx_hashes, idx_offsets, idx_count, target_hash, &off_rel);
  if (!found) { CommPrint(1, "SEE_ERR not_found\n"); Free(idx_hashes); Free(idx_offsets); return; }
  I64 off = 16 + off_rel; // Index offsets are relative to the object
                           // section (rbuf+16) - see probe 12/19/20's
                           // recurring lesson.
  U8 obj_type = rbuf[off+8];
  if (obj_type != OBJ_COMMIT) { CommPrint(1, "SEE_ERR not_a_commit type=%d\n", obj_type); Free(idx_hashes); Free(idx_offsets); return; }
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

  // Probe 112 (experiments/112-see-parent-hashes/): `parents=%d` only
  // ever showed the COUNT, never which commits they actually were -
  // a real gap for a merge commit specifically (the only real case
  // with more than one), where "how many parents" alone doesn't tell
  // a user which two histories were joined. One SEE_PARENT line per
  // parent, in the same real order Commit.HC's own encoding stores
  // them (ours first, theirs second, for a real merge commit -
  // Merge.HC's own convention).
  for (i=0; i<pcount; i++) {
    U8 *ph = CommitParentHash(content, i);
    U8 ph_hex[129];
    HashToHex(ph, ph_hex);
    CommPrint(1, "SEE_PARENT %s\n", ph_hex);
  }

  U8 rel_tag = CommitRelationTag(content);
  if (rel_tag != REL_NONE) {
    U8 *rel_target = CommitRelationTarget(content);
    U8 rel_hex[129];
    HashToHex(rel_target, rel_hex);
    U64 rel_entity_id = CommitRelationEntityId(content); // ADR 0006
    U8 rel_entity_hex[17];
    U64ToHex(rel_entity_id, rel_entity_hex);
    CommPrint(1, "SEE_RELATION tag=%d target=%s entity=%s\n",
              rel_tag, rel_hex, rel_entity_hex);
  }

  I64 tree_off_rel;
  Bool tree_found = IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &tree_off_rel);
  if (!tree_found) { CommPrint(1, "SEE_ERR tree_not_found\n"); Free(idx_hashes); Free(idx_offsets); return; }
  I64 tree_off = 16 + tree_off_rel;
  U64 tree_len = GetU64LE(rbuf, tree_off);
  U8 *tree_content = rbuf + tree_off + 9;

  U32 tcount = GetU32LE(tree_content, 0);
  CommPrint(1, "SEE_TREE entries=%d\n", tcount);
  SeePrintTreeEntries(rbuf, idx_hashes, idx_offsets, idx_count, tree_content, 0);
  CommPrint(1, "SEE_END\n");
  Free(idx_hashes);
  Free(idx_offsets);
}
// Diff.HC — `hgit diff <repo> <commit_hex>`: show what changed in one
// commit relative to its own parent's tree (or, for a root commit
// with no parent, every entry is new). For a real merge commit (ADR
// 0011), "its own parent" means specifically the FIRST parent
// (`ours` at merge time) - the same convention `git show`/`git log -p`
// use by default for a merge - not a special case added for merge
// commits, just this file's own pre-existing single-parent behavior
// applied unchanged. Confirmed sane against a real merge commit
// (probe 111, `experiments/111-diff-on-merge-commit/`): a file that
// only entered the tree via the merge's SECOND parent correctly shows
// as `DIFF_NEW`, since it wasn't present in the first parent's own
// tree - not a crash, not a wrong answer, a real and coherent (if
// partial) view.
//
// This is the per-commit counterpart to `hgit status`'s own
// working-directory-vs-HEAD-tree diff (`Status.HC`) - same
// classification vocabulary (NEW/MODIFIED/DELETED/RENAMED, both exact-
// content and fuzzy), same two-pass rename-matching logic, just
// comparing two COMMITTED trees instead of a live directory against
// one. Closes the "hgit history/reconciledoc don't surface renames"
// gap ADR 0009 left open (probes 71/85 only covered `status`) - not by
// changing `history`'s own per-line format, but by giving renames (and
// every other kind of change) a real, dedicated place to be shown per
// commit.
//
// Simpler than `Status.HC` in one real way: both sides here are
// already-stored blobs, so content for a fuzzy-match candidate is
// always resolved via the index (IndexLookup + rbuf), never a live
// FileRead - no need to buffer full file content ahead of time the way
// `Status.HC`'s NEW-on-disk candidates require.
//
// Recurses into nested trees (ADR 0010, experiments/94-diff-nested-
// trees/) - the same generic-per-object-type recursion pattern this
// project already established (Check.HC's CheckMarkReachable, See.HC's
// SeePrintTreeEntries): a subdirectory entry whose own hash changed is
// diffed recursively instead of just reported as one opaque
// "MODIFIED <dirname>" line, and a wholly new/deleted subdirectory is
// recursed into against an empty tree, so every real nested file gets
// its own DIFF_NEW/DIFF_DELETED line (prefixed with its real path,
// e.g. "SubA/inner.txt") instead of naming only the directory once.
// Deliberately out of scope, same as ADR 0010's own deferred item:
// cross-directory rename detection, and a same-name entry that
// changes KIND (file<->directory) - reported as a real, honest
// DIFF_TYPE_CHANGED signal, not silently mis-diffed as a content
// change or guessed at either side.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Tree.HC, Index.HC, Fossil.HC, Hex.HC.

// Resolves a tree object's own content/length by its hash, via the
// same IndexLookup every other real command uses. Returns FALSE (not
// a crash) if the hash isn't in the index - a broken reference is
// Check.HC's own job to report, not this file's.
Bool DiffResolveTreeByHash(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                           U8 *hash, U8 **out_content, I64 *out_len)
{
  I64 off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, hash, &off_rel)) return FALSE;
  I64 off = 16 + off_rel;
  U64 rec_len = GetU64LE(rbuf, off);
  *out_content = rbuf + off + 9;
  *out_len = rec_len - 1;
  return TRUE;
}

// Diffs one tree level (old vs new, either side may be NULL - a real,
// valid base case for recursing into a wholly new/deleted
// subdirectory against an empty tree, not a special case needing its
// own logic), printing every real change with `prefix` prepended to
// its name (e.g. "SubA/"). Recurses into any OBJ_TREE entry whose own
// hash changed, or that's wholly new/deleted, one directory level at
// a time.
U0 DiffPrintTreeChanges(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                        U8 *old_tree_content, I64 old_tree_content_len,
                        U8 *new_tree_content, I64 new_tree_content_len,
                        U8 *prefix)
{
  U32 new_tcount = 0;
  if (new_tree_content != NULL) new_tcount = GetU32LE(new_tree_content, 0);
  U32 old_tcount = 0;
  if (old_tree_content != NULL) old_tcount = GetU32LE(old_tree_content, 0);

  // Buffers sized from each tree's own exact entry count (already
  // known, same "no premature fixed cap" discipline every other
  // MAlloc'd index/buffer in this project already follows). Only
  // OBJ_BLOB entries ever populate these - a tree entry is either
  // handled immediately (recursed into) or reported directly, never
  // buffered as a rename candidate (see file header).
  U8 *new_names = MAlloc(new_tcount*256 + 256);
  U8 *new_hashes = MAlloc(new_tcount*64 + 64);
  Bool *new_matched = MAlloc(new_tcount + 1);
  I64 new_count = 0;

  U8 *del_names = MAlloc(old_tcount*256 + 256);
  U8 *del_hashes = MAlloc(old_tcount*64 + 64);
  Bool *del_matched = MAlloc(old_tcount + 1);
  I64 del_count = 0;

  I64 pos = 4;
  U32 te;
  I64 i;
  if (new_tree_content != NULL) {
    for (te=0; te<new_tcount; te++) {
      U8 nlen = new_tree_content[pos]; pos += 1;
      U8 *name = new_tree_content + pos; pos += nlen;
      U8 new_type = new_tree_content[pos]; pos += 1;
      U8 *hash = new_tree_content + pos; pos += 64;
      pos += 8; // entity_id - not needed here

      U8 full_name[256];
      I64 fi = 0, fj;
      for (fj=0; prefix[fj]; fj++) full_name[fi++] = prefix[fj];
      I64 cap = nlen; if (fi + cap > 254) cap = 254 - fi;
      for (fj=0; fj<cap; fj++) full_name[fi++] = name[fj];
      full_name[fi] = 0;

      Bool found_by_name = FALSE;
      U8 old_type;
      U8 old_hash[64];
      U64 old_entity_id;
      if (old_tree_content != NULL) {
        found_by_name = TreeFindEntry(old_tree_content, old_tree_content_len,
                                      name, nlen, &old_type, old_hash, &old_entity_id);
      }

      if (new_type == OBJ_TREE) {
        if (found_by_name && old_type == OBJ_TREE) {
          Bool same_a = TRUE;
          for (i=0; i<64; i++) if (hash[i] != old_hash[i]) same_a = FALSE;
          if (!same_a) {
            U8 *sub_old_content_a = NULL; I64 sub_old_len_a = 0;
            U8 *sub_new_content_a = NULL; I64 sub_new_len_a = 0;
            DiffResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                                 old_hash, &sub_old_content_a, &sub_old_len_a);
            DiffResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                                 hash, &sub_new_content_a, &sub_new_len_a);
            U8 sub_prefix_a[256];
            I64 spi_a=0, spj_a;
            for (spj_a=0; full_name[spj_a]; spj_a++) sub_prefix_a[spi_a++] = full_name[spj_a];
            sub_prefix_a[spi_a++] = '/'; sub_prefix_a[spi_a] = 0;
            DiffPrintTreeChanges(rbuf, idx_hashes, idx_offsets, idx_count,
                                 sub_old_content_a, sub_old_len_a,
                                 sub_new_content_a, sub_new_len_a, sub_prefix_a);
          }
        } else if (found_by_name) {
          // Same name, old side isn't a tree - a real kind-change
          // (file->directory), deliberately out of scope (see file
          // header): report it plainly, don't guess at either side.
          CommPrint(1, "DIFF_TYPE_CHANGED ");
          for (i=0; full_name[i]; i++) CommPrint(1, "%c", full_name[i]);
          CommPrint(1, "\n");
        } else {
          // A wholly new subdirectory - recurse against an empty old
          // tree so every real nested entry gets its own DIFF_NEW
          // line, not just one line naming the directory.
          U8 *sub_new_content_b = NULL; I64 sub_new_len_b = 0;
          DiffResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                               hash, &sub_new_content_b, &sub_new_len_b);
          U8 sub_prefix_b[256];
          I64 spi_b=0, spj_b;
          for (spj_b=0; full_name[spj_b]; spj_b++) sub_prefix_b[spi_b++] = full_name[spj_b];
          sub_prefix_b[spi_b++] = '/'; sub_prefix_b[spi_b] = 0;
          DiffPrintTreeChanges(rbuf, idx_hashes, idx_offsets, idx_count,
                               NULL, 0, sub_new_content_b, sub_new_len_b, sub_prefix_b);
        }
      } else {
        // OBJ_BLOB: unchanged from before - same name/same type in old
        // tree -> UNCHANGED (silent) or MODIFIED (printed immediately);
        // no match by name -> buffered as a rename candidate.
        if (found_by_name && old_type == OBJ_BLOB) {
          Bool same_b = TRUE;
          for (i=0; i<64; i++) if (hash[i] != old_hash[i]) same_b = FALSE;
          if (!same_b) {
            CommPrint(1, "DIFF_MODIFIED ");
            for (i=0; full_name[i]; i++) CommPrint(1, "%c", full_name[i]);
            CommPrint(1, "\n");
          }
        } else if (found_by_name) {
          CommPrint(1, "DIFF_TYPE_CHANGED ");
          for (i=0; full_name[i]; i++) CommPrint(1, "%c", full_name[i]);
          CommPrint(1, "\n");
        } else {
          I64 ncap = fi; if (ncap > 254) ncap = 254;
          for (i=0; i<ncap; i++) new_names[new_count*256+i] = full_name[i];
          new_names[new_count*256+ncap] = 0;
          for (i=0; i<64; i++) new_hashes[new_count*64+i] = hash[i];
          new_matched[new_count] = FALSE;
          new_count++;
        }
      }
    }
  }

  // Deletion pass over the old tree: an entry found in the new tree by
  // name (any type) was already handled above (unchanged/modified/
  // recursed/type-changed) - skip it here to avoid double-reporting.
  if (old_tree_content != NULL) {
    I64 opos = 4;
    U32 oe;
    for (oe=0; oe<old_tcount; oe++) {
      U8 onlen = old_tree_content[opos]; opos += 1;
      U8 *oname = old_tree_content + opos; opos += onlen;
      U8 old_type2 = old_tree_content[opos]; opos += 1;
      U8 *ohash = old_tree_content + opos; opos += 64;
      opos += 8; // entity_id

      U8 dummy_type;
      U8 dummy_hash[64];
      U64 dummy_entity_id;
      Bool found_in_new = FALSE;
      if (new_tree_content != NULL) {
        found_in_new = TreeFindEntry(new_tree_content, new_tree_content_len,
                                     oname, onlen, &dummy_type, dummy_hash, &dummy_entity_id);
      }
      if (!found_in_new) {
        U8 full_oname[256];
        I64 ofi = 0, ofj;
        for (ofj=0; prefix[ofj]; ofj++) full_oname[ofi++] = prefix[ofj];
        I64 ocap = onlen; if (ofi + ocap > 254) ocap = 254 - ofi;
        for (ofj=0; ofj<ocap; ofj++) full_oname[ofi++] = oname[ofj];
        full_oname[ofi] = 0;

        if (old_type2 == OBJ_TREE) {
          // A wholly deleted subdirectory - recurse against an empty
          // new tree so every real nested entry gets its own
          // DIFF_DELETED line.
          U8 *sub_old_content_c = NULL; I64 sub_old_len_c = 0;
          DiffResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                               ohash, &sub_old_content_c, &sub_old_len_c);
          U8 sub_prefix_c[256];
          I64 spi_c=0, spj_c;
          for (spj_c=0; full_oname[spj_c]; spj_c++) sub_prefix_c[spi_c++] = full_oname[spj_c];
          sub_prefix_c[spi_c++] = '/'; sub_prefix_c[spi_c] = 0;
          DiffPrintTreeChanges(rbuf, idx_hashes, idx_offsets, idx_count,
                               sub_old_content_c, sub_old_len_c, NULL, 0, sub_prefix_c);
        } else {
          I64 dcap = ofi; if (dcap > 254) dcap = 254;
          for (i=0; i<dcap; i++) del_names[del_count*256+i] = full_oname[i];
          del_names[del_count*256+dcap] = 0;
          for (i=0; i<64; i++) del_hashes[del_count*64+i] = ohash[i];
          del_matched[del_count] = FALSE;
          del_count++;
        }
      }
    }
  }

  // Rename pass 1: exact content match, same "first match wins"
  // simplification every other rename check in this project documents.
  // Blob-only, same as before - a tree's own serialized content isn't
  // meaningful to compare this way (see file header).
  I64 di, ni;
  for (di=0; di<del_count; di++) {
    for (ni=0; ni<new_count; ni++) {
      Bool hmatch = !new_matched[ni];
      I64 hi;
      if (hmatch) for (hi=0; hi<64; hi++) if (del_hashes[di*64+hi] != new_hashes[ni*64+hi]) hmatch = FALSE;
      if (hmatch) {
        CommPrint(1, "DIFF_RENAMED %s -> %s\n", del_names+di*256, new_names+ni*256);
        new_matched[ni] = TRUE;
        del_matched[di] = TRUE;
        ni = new_count;
      }
    }
  }

  // Rename pass 2: fuzzy match (ADR 0008/0009, Fossil.HC's own
  // similarity measure), same git-style -M50% threshold Offer.HC and
  // Status.HC already use. Both sides resolved on demand via the
  // index - no content buffering needed ahead of time, since both are
  // already-stored blobs.
  for (di=0; di<del_count; di++) {
    if (!del_matched[di]) {
      I64 del_off_rel;
      if (IndexLookup(idx_hashes, idx_offsets, idx_count, del_hashes+di*64, &del_off_rel)) {
        I64 del_off = 16 + del_off_rel;
        U64 del_rec_len = GetU64LE(rbuf, del_off);
        U8 *del_content = rbuf + del_off + 9;
        I64 del_content_len = del_rec_len - 1;

        I64 best_ni = -1, best_sim = -1;
        for (ni=0; ni<new_count; ni++) {
          if (!new_matched[ni]) {
            I64 new_off_rel;
            if (IndexLookup(idx_hashes, idx_offsets, idx_count, new_hashes+ni*64, &new_off_rel)) {
              I64 new_off = 16 + new_off_rel;
              U64 new_rec_len = GetU64LE(rbuf, new_off);
              U8 *new_content = rbuf + new_off + 9;
              I64 new_content_len = new_rec_len - 1;
              I64 sim = FossilSimilarityPercent(del_content, del_content_len,
                                                new_content, new_content_len);
              if (sim > best_sim) { best_sim = sim; best_ni = ni; }
            }
          }
        }
        if (best_ni >= 0 && best_sim >= FOSSIL_RENAME_SIMILARITY_THRESHOLD) {
          CommPrint(1, "DIFF_RENAMED %s -> %s\n", del_names+di*256, new_names+best_ni*256);
          new_matched[best_ni] = TRUE;
          del_matched[di] = TRUE;
        }
      }
    }
  }

  for (ni=0; ni<new_count; ni++) {
    if (!new_matched[ni]) CommPrint(1, "DIFF_NEW %s\n", new_names+ni*256);
  }
  for (di=0; di<del_count; di++) {
    if (!del_matched[di]) CommPrint(1, "DIFF_DELETED %s\n", del_names+di*256);
  }

  Free(new_names);
  Free(new_hashes);
  Free(new_matched);
  Free(del_names);
  Free(del_hashes);
  Free(del_matched);
}

U0 HgitDiff(U8 *repo_path, U8 *commit_hash)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "DIFF_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "DIFF_ERR bad_header\n"); return; }

  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 c_off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, commit_hash, &c_off_rel)) {
    CommPrint(1, "DIFF_ERR commit_not_found\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  I64 c_off = 16 + c_off_rel;
  U8 c_type = rbuf[c_off+8];
  if (c_type != OBJ_COMMIT) {
    CommPrint(1, "DIFF_ERR not_a_commit type=%d\n", c_type);
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  U8 *c_content = rbuf + c_off + 9;
  U8 *new_tree_hash = CommitTreeHash(c_content);

  I64 nt_off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, new_tree_hash, &nt_off_rel)) {
    CommPrint(1, "DIFF_ERR tree_not_found\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  I64 nt_off = 16 + nt_off_rel;
  U64 nt_rec_len = GetU64LE(rbuf, nt_off);
  U8 *new_tree_content = rbuf + nt_off + 9;
  I64 new_tree_content_len = nt_rec_len - 1;

  U8 *old_tree_content = NULL;
  I64 old_tree_content_len = 0;
  U8 pcount = CommitParentCount(c_content);
  if (pcount > 0) {
    U8 *parent_hash = CommitParentHash(c_content, 0);
    I64 p_off_rel;
    if (IndexLookup(idx_hashes, idx_offsets, idx_count, parent_hash, &p_off_rel)) {
      I64 p_off = 16 + p_off_rel;
      U8 *p_content = rbuf + p_off + 9;
      U8 *old_tree_hash = CommitTreeHash(p_content);
      I64 ot_off_rel;
      if (IndexLookup(idx_hashes, idx_offsets, idx_count, old_tree_hash, &ot_off_rel)) {
        I64 ot_off = 16 + ot_off_rel;
        U64 ot_rec_len = GetU64LE(rbuf, ot_off);
        old_tree_content = rbuf + ot_off + 9;
        old_tree_content_len = ot_rec_len - 1;
      }
    }
  }

  U8 root_prefix[1]; root_prefix[0] = 0;
  DiffPrintTreeChanges(rbuf, idx_hashes, idx_offsets, idx_count,
                       old_tree_content, old_tree_content_len,
                       new_tree_content, new_tree_content_len, root_prefix);

  CommPrint(1, "DIFF_END\n");

  Free(idx_hashes);
  Free(idx_offsets);
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
// since objects are content-addressed). `archive` and each matched
// file's own blob buffer are now `MAlloc`'d at a real computed size,
// not fixed stack arrays, in BOTH the flat `hgit offer` path (probe
// 106) and the recursive `offertree` path (probe 107) - only the
// per-directory-level `tree_content[2048]`/`tree_content[4096]`
// entry-COUNT caps (unrelated to file byte size) remain real, known,
// not-yet-hit limits. `find_mask` also still
// has to be passed in rather than "the whole repo directory minus the
// repo's own files" (no self-exclusion logic yet).
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC, Object.HC,
// Tree.HC, Commit.HC (the whole hgit-core object layer),
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
// (Tree.HC's GenerateEntityId).
//
// Per ADR 0009 (experiments/70-rename-detection/): if the name isn't
// found, the file's CONTENT hash is also checked against the parent
// tree (TreeFindEntryByHash) before falling back to a fresh ID - exact
// -content rename detection, closing the gap ADR 0004 itself deferred.
// A rename with an edit in the same offer still isn't detected (looks
// new either way) - see ADR 0009's own "what this slice does not do".
//
// Per ADR 0005 (experiments/51-relation-commands/): HgitOffer itself
// is now a thin wrapper over HgitOfferWithRelation (REL_NONE/NULL),
// defined first since HolyC has no forward declarations - a call to a
// not-yet-defined function later in the same push fails to compile -
// `hgit correct`/`hgit revert`/`hgit reconcile` call the same
// underlying logic with a real relation attached, rather than
// duplicating the whole offer process.

// ADR 0007 (experiments/61-dynamic-archive/): headroom reserved above
// the existing repo's own size for this call's new objects, and a
// purely pathological-input sanity ceiling.
//
// ARCHIVE_HEADROOM is a real computed worst case, not a guess, given
// probe 56's own still-in-place guards: tree_content[2048] caps at
// ~27 entries (2048 / a 75-byte minimal single-char-name entry), each
// of which can carry up to a 511-byte blob (blob_tagged[512]'s own
// cap) - 27*511 ~ 13800 bytes of blob content, plus the tree object's
// own up-to-2048 bytes, plus a commit up to 512, plus ~9 bytes of HGS
// record overhead per object (~29 objects worst case ~ 260 bytes).
// That worst case totals ~16600 bytes; 20000 leaves real margin and
// matches the exact size independently confirmed safe via MAlloc in
// experiments/61-dynamic-archive/.
//
// No longer used by either `HgitOfferWithRelation` (flat `hgit offer`,
// probe 106) or `HgitOfferTreeWithRelation` (`offertree`, probe 107) -
// both now compute a real capacity from the actual files being
// offered instead (see OBJECT_RECORD_OVERHEAD/TREE_COMMIT_HEADROOM and
// TREE_LEVEL_MAX/COMMIT_HEADROOM below). Left defined and documented
// here as historical record of the worst-case reasoning ADR 0007
// originally established, not because anything still uses it.
#define ARCHIVE_HEADROOM 20000
#define ARCHIVE_SANITY_MAX 1000000000

// Probe 106 (experiments/106-offer-large-file-support/): now that
// probe 105 removed `ObjectPut`'s own shared `tagged[4096]` ceiling,
// the flat `hgit offer` path's own per-file `fsize+1 > 512` skip was
// no longer inherited from anywhere deeper - lifted here, backed by a
// real COMPUTED archive capacity instead of a fixed headroom: a first
// `FilesFind` pass over the same `find_mask` sums every matched
// entry's own real `size` field (no `FileRead` needed just to size -
// `CDirEntry`'s own `size` field, confirmed real via
// `Kernel/BlkDev/FileSysFAT.HC`'s own `tmpde->size=de->size`) before
// `archive` is `MAlloc`'d, so a large offered file's own real bytes
// are accounted for exactly rather than assumed to fit inside a fixed
// per-file cap. `OBJECT_RECORD_OVERHEAD` is `HgsPut`'s own fixed
// per-record cost (8-byte length + 1-byte type tag + 64-byte hash =
// 73, `Hgs.HC`'s own record shape). `TREE_COMMIT_HEADROOM` covers the
// still-in-place `tree_content[2048]` entry-count cap (unrelated to
// file byte size, not removed here) plus its own record overhead,
// plus a generous fixed bound for the commit object and its own
// record overhead.
#define OBJECT_RECORD_OVERHEAD 73
#define TREE_COMMIT_HEADROOM 3000

// Probe 107 (experiments/107-offertree-large-file-support/):
// `HgitOfferTreeWithRelation` (`offertree`) needs its own headroom
// formula, not `TREE_COMMIT_HEADROOM` above - unlike the flat path,
// it can create MULTIPLE tree objects (one per real subdirectory,
// `TreeBuildRecursive`'s own recursion), each up to a real per-level
// entry-content cap. `TREE_LEVEL_MAX` matches the largest per-level
// buffer actually used (`HgitOfferTreeWithRelation`'s own root-level
// `tree_content[4096]`; nested nested levels use a smaller
// `child_tree_content[2048]`, so 4096 is a safe, real upper bound, not
// a guess) plus that tree's own record overhead, times (subdirectory
// count + 1 for the root tree itself).
#define TREE_LEVEL_MAX 4096
#define COMMIT_HEADROOM 600

// ADR 0009 addendum (experiments/84-fuzzy-rename-detection/): a
// currently-offered file's content must score at least
// `FOSSIL_RENAME_SIMILARITY_THRESHOLD` similar (`FossilSimilarityPercent`,
// `Fossil.HC`'s own shared threshold - also used by `Status.HC`) to
// some old, name-unmatched blob before its identity is carried forward
// this way.

// Third fallback in the entity-ID chain (name match, then exact-hash
// match, now this): scans every BLOB entry in the parent's own tree
// and, for each, resolves its actual content (via the same
// old_idx_hashes/old_idx_offsets/rbuf the caller already built for the
// exact-hash path) and scores it against `target_content` with
// Fossil's own similarity measure (ADR 0008,
// experiments/83-fossil-similarity/). Returns the BEST-scoring
// candidate's entity ID if it meets FOSSIL_RENAME_SIMILARITY_THRESHOLD,
// FALSE otherwise. Same "first/best match wins, no cross-file
// disambiguation" simplification ADR 0009 already documents for its
// own exact-content matching: this doesn't check whether some OTHER
// file in the same offering already exactly matched this same old
// entry - a real, documented limitation, not a hidden bug (see this
// probe's own README).
Bool OfferFindFuzzyRename(U8 *rbuf, U8 *old_tree_content, I64 old_tree_content_len,
                          U8 *old_idx_hashes, I64 *old_idx_offsets, I64 old_idx_count,
                          U8 *target_content, I64 target_content_len,
                          U64 *entity_id_out)
{
  U32 count = GetU32LE(old_tree_content, 0);
  I64 pos = 4;
  U32 e;
  I64 best_sim = -1;
  U64 best_entity_id = 0;
  for (e=0; e<count; e++) {
    U8 name_len = old_tree_content[pos]; pos += 1;
    pos += name_len;
    U8 child_type = old_tree_content[pos]; pos += 1;
    U8 *child_hash = old_tree_content + pos; pos += 64;
    U64 this_entity_id = GetU64LE(old_tree_content, pos); pos += 8;

    if (child_type == OBJ_BLOB) {
      I64 off_rel;
      if (IndexLookup(old_idx_hashes, old_idx_offsets, old_idx_count, child_hash, &off_rel)) {
        I64 off = 16 + off_rel;
        U64 rec_len = GetU64LE(rbuf, off);
        U8 *content = rbuf + off + 9; // skip the OBJ_BLOB type tag byte
        I64 content_len = rec_len - 1;
        I64 sim = FossilSimilarityPercent(content, content_len,
                                          target_content, target_content_len);
        if (sim > best_sim) {
          best_sim = sim;
          best_entity_id = this_entity_id;
        }
      }
    }
  }
  if (best_sim >= FOSSIL_RENAME_SIMILARITY_THRESHOLD) {
    *entity_id_out = best_entity_id;
    return TRUE;
  }
  return FALSE;
}

// Probe 107 (experiments/107-offertree-large-file-support/): a real,
// computed sum of every real file's own size across the WHOLE subtree
// under dir_path, plus a subdirectory count - mirrors
// TreeBuildRecursive's own recursion, dot/dotdot skip, and
// `attr & 16` subdirectory check below, but only sums (never writes
// to `archive`), so `HgitOfferTreeWithRelation` can size `archive`
// correctly instead of assuming a fixed per-file/per-tree cap.
U0 SumTreeFileBytes(U8 *dir_path, I64 *bytes_out, I64 *file_count_out, I64 *subdir_count_out)
{
  U8 mask[256];
  StrPrint(mask, "%s*", dir_path);
  CDirEntry *tmpde = FilesFind(mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    Bool is_dot = StrCmp(tmpde->full_name+name_start, ".") == 0;
    Bool is_dotdot = StrCmp(tmpde->full_name+name_start, "..") == 0;
    if (!is_dot && !is_dotdot) {
      if (tmpde->attr & 16) {
        *subdir_count_out += 1;
        U8 subdir_path[256];
        StrPrint(subdir_path, "%s/", tmpde->full_name);
        SumTreeFileBytes(subdir_path, bytes_out, file_count_out, subdir_count_out);
      } else {
        *bytes_out += tmpde->size;
        *file_count_out += 1;
      }
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
}

// ADR 0010 (experiments/90-recursive-tree-primitive/): a real,
// standalone, tested recursive tree-building primitive - NOT wired
// into `HgitOfferWithRelation`'s own live dispatch below (see that
// ADR's own "what this slice does not do"). Recursively builds a tree
// object from a real directory (`dir_path`, trailing "/" required):
// each plain file becomes an OBJ_BLOB entry, each subdirectory
// (`CDirEntry.attr & 16`, probe 88) becomes a nested OBJ_TREE entry,
// built depth-first (children stored via ObjectPut before their own
// parent tree, since a tree's hash needs its full content first -
// exactly proven possible, with zero object-model changes, in probe
// 89). Entity-ID/rename continuity (exact name, exact content hash,
// then fuzzy) is resolved at EACH directory level independently,
// against whichever old tree matches that same relative directory
// position in the parent commit - a file moved to a *different*
// directory is not identity-tracked across that move in this slice
// (ADR 0010's own explicit scope decision), only renamed/edited
// within the same directory.
//
// `tree_content_out` must be sized generously by the caller (same
// "no premature fixed-cap tuning" stance as `Offer.HC`'s own
// `tree_content[2048]` - a real, known limit, not yet hit by anything
// tested, same as here).
U0 TreeBuildRecursive(U8 *dir_path, U8 *archive, I64 *alen,
                      U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                      U8 *old_tree_content, I64 old_tree_content_len,
                      U8 *tree_content_out, I64 *tree_content_len_out)
{
  I64 tlen = 4; // room for entry_count, filled in at the end
  I64 entry_count = 0;

  U8 mask[256];
  StrPrint(mask, "%s*", dir_path);
  CDirEntry *tmpde = FilesFind(mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;
    Bool is_dot = StrCmp(tmpde->full_name+name_start, ".") == 0;
    Bool is_dotdot = StrCmp(tmpde->full_name+name_start, "..") == 0;

    if (!is_dot && !is_dotdot) {
      if (tmpde->attr & 16) {
        // Subdirectory: resolve the matching OLD subtree at this same
        // relative position (if any) to pass down as the "old tree"
        // for the recursive call - the same by-name lookup
        // TreeFindEntry already does, just for a tree-typed entry.
        U8 old_sub_type;
        U8 old_sub_hash[64];
        U64 old_sub_entity_id;
        U8 *old_sub_tree_content = NULL;
        I64 old_sub_tree_content_len = 0;
        Bool found_old_sub = FALSE;
        if (old_tree_content != NULL) {
          found_old_sub = TreeFindEntry(old_tree_content, old_tree_content_len,
                                        tmpde->full_name+name_start, name_len,
                                        &old_sub_type, old_sub_hash, &old_sub_entity_id);
          if (found_old_sub && old_sub_type == OBJ_TREE) {
            I64 sub_off_rel;
            if (IndexLookup(idx_hashes, idx_offsets, idx_count, old_sub_hash, &sub_off_rel)) {
              I64 sub_off = 16 + sub_off_rel;
              U64 sub_rec_len = GetU64LE(rbuf, sub_off);
              old_sub_tree_content = rbuf + sub_off + 9;
              old_sub_tree_content_len = sub_rec_len - 1;
            }
          } else {
            found_old_sub = FALSE; // same name existed but wasn't a
                                     // tree (e.g. a file replaced by a
                                     // directory) - no old identity to
                                     // carry forward.
          }
        }

        U8 subdir_path[256];
        StrPrint(subdir_path, "%s/", tmpde->full_name);
        U8 child_tree_content[2048];
        I64 child_tree_content_len;
        TreeBuildRecursive(subdir_path, archive, alen, rbuf, idx_hashes, idx_offsets, idx_count,
                           old_sub_tree_content, old_sub_tree_content_len,
                           child_tree_content, &child_tree_content_len);

        U8 child_tagged[2048];
        child_tagged[0] = OBJ_TREE;
        I64 ci;
        for (ci=0; ci<child_tree_content_len; ci++) child_tagged[1+ci] = child_tree_content[ci];
        U8 child_hash[64];
        B2Hash512Any(child_tagged, child_tree_content_len+1, child_hash);
        ObjectPut(archive, alen, OBJ_TREE, child_tree_content, child_tree_content_len);

        U64 sub_entity_id;
        if (found_old_sub) sub_entity_id = old_sub_entity_id;
        else sub_entity_id = GenerateEntityId();

        TreeEncodeEntry(tree_content_out, &tlen, tmpde->full_name+name_start, name_len,
                        OBJ_TREE, child_hash, sub_entity_id);
        entry_count++;
      } else {
        // Regular file: the same blob-storage + entity-ID logic
        // HgitOfferWithRelation's own flat loop already uses,
        // parameterized by THIS directory level's own old tree.
        I64 fsize;
        U8 *fbuf = FileRead(tmpde->full_name, &fsize);
        {
          // Probe 107: was `if (fsize+1 <= 512)` guarding a fixed
          // `blob_tagged[512]` stack buffer - a file over 511 bytes
          // was silently DROPPED here (no message at all, worse than
          // the flat path's old `OFFER_SKIP`). `MAlloc`'d at the
          // file's own real size instead, same fix as probe 106's
          // flat-path version; `archive` itself is now sized by a
          // real recursive sum (`SumTreeFileBytes`, above) rather than
          // a fixed headroom, so this no longer risks overflowing it.
          U8 *blob_tagged = MAlloc(fsize+1);
          blob_tagged[0] = OBJ_BLOB;
          I64 bi;
          for (bi=0; bi<fsize; bi++) blob_tagged[1+bi] = fbuf[bi];
          U8 blob_hash[64];
          B2Hash512Any(blob_tagged, fsize+1, blob_hash);
          Free(blob_tagged);
          ObjectPut(archive, alen, OBJ_BLOB, fbuf, fsize);

          U64 entity_id;
          Bool found_old = FALSE;
          if (old_tree_content != NULL) {
            U8 old_type;
            U8 old_hash[64];
            found_old = TreeFindEntry(old_tree_content, old_tree_content_len,
                                      tmpde->full_name+name_start, name_len,
                                      &old_type, old_hash, &entity_id);
            if (!found_old) {
              found_old = TreeFindEntryByHash(old_tree_content, old_tree_content_len,
                                              blob_hash, &entity_id);
            }
            if (!found_old) {
              found_old = OfferFindFuzzyRename(rbuf, old_tree_content, old_tree_content_len,
                                               idx_hashes, idx_offsets, idx_count,
                                               fbuf, fsize, &entity_id);
            }
          }
          if (!found_old) entity_id = GenerateEntityId();

          TreeEncodeEntry(tree_content_out, &tlen, tmpde->full_name+name_start, name_len,
                          OBJ_BLOB, blob_hash, entity_id);
          entry_count++;
        }
      }
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
  PutU32LE(tree_content_out, 0, entry_count);
  *tree_content_len_out = tlen;
}

U0 HgitOfferWithRelation(U8 *repo_path, U8 *find_mask, U8 *message, I64 message_len,
                          U64 timestamp, U8 relation_tag, U8 *relation_target,
                          U64 relation_entity_id)
{
  // Load the existing repo's object section into a working buffer.
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  // ADR 0007 (experiments/61-dynamic-archive/): `archive` used to be a
  // fixed `U8[8192]` stack buffer - probe 60 found and bisected a real
  // kernel GPF once a repo's own growth alone (no wildcards, no large
  // files - each offer/correct grows a real repo by ~600 bytes) crossed
  // that ceiling, and probe 60's own fix was a clean refusal rather
  // than lifting the ceiling. This does that: `archive` is now
  // `MAlloc`'d at exactly the size this call needs (the existing repo
  // plus a generous, still-bounded headroom for this call's own new
  // objects - probe 56's own per-file/tree caps already bound that
  // upper end), freed on every exit path. `ARCHIVE_SANITY_MAX` is a
  // much higher, purely pathological-input ceiling (guards against a
  // corrupted/absurd `rsize`, not real growth) - confirmed via
  // `experiments/61-dynamic-archive/` that a 20,000-byte `MAlloc`
  // writes/reads back correctly with no corruption; `MAlloc`/`Free` are
  // real TempleOS kernel primitives, already relied on implicitly by
  // this project's own daemon bootstrap.
  if (rsize > ARCHIVE_SANITY_MAX) {
    CommPrint(1, "OFFER_REFUSED archive_absurdly_large size=%d\n", rsize);
    return;
  }

  // Probe 106: a real, computed capacity (sum of every matched file's
  // own real size, via CDirEntry->size - no FileRead needed just to
  // size) rather than a fixed headroom, so a large offered file's own
  // bytes are always accounted for exactly.
  I64 new_content_bytes = 0;
  I64 new_file_count = 0;
  CDirEntry *size_de = FilesFind(find_mask, 0);
  CDirEntry *size_de1 = size_de;
  while (size_de) {
    new_content_bytes += size_de->size;
    new_file_count++;
    size_de = size_de->next;
  }
  DirTreeDel(size_de1);

  I64 archive_cap = rsize + new_content_bytes
                   + new_file_count * OBJECT_RECORD_OVERHEAD
                   + TREE_COMMIT_HEADROOM;
  if (archive_cap > ARCHIVE_SANITY_MAX) {
    CommPrint(1, "OFFER_REFUSED archive_absurdly_large size=%d\n", archive_cap);
    return;
  }
  U8 *archive = MAlloc(archive_cap);
  I64 alen = 16; // header goes here at the end, once we know the count
  I64 i;
  for (i = 0; i < rsize-16; i++) archive[16+i] = rbuf[16+i];
  alen = rsize;

  // Parent lookup happens BEFORE building the new tree, so each file's
  // entity ID can be carried forward from the parent's own tree.
  U8 parent_hash[64];
  Bool has_parent = CurrentHeadRead(repo_path, parent_hash);

  // Same class of fixed-buffer bug ADR 0007 fixed for `archive` -
  // `idx_hashes`/`idx_offsets` used to be `[64*64]`/`[64]` stack arrays,
  // a hardcoded cap of 64 *objects total in the whole repo* (not 64
  // matched files). Confirmed hit in practice while re-verifying ADR
  // 0007's own fix (experiments/61-dynamic-archive/): once
  // `archive`'s ceiling was lifted, real growth continued until this
  // *next* fixed buffer overflowed instead, at ~22 offers (66+ objects
  // - 3 objects/offer). Same fix, same pattern: MAlloc'd from `rcount`
  // (already known exactly from the .HGS header - no headroom guess
  // needed, this one is an exact count by construction), freed right
  // after this block's last use of it.
  U8 *old_idx_hashes = MAlloc(rcount*64 + 64);
  I64 *old_idx_offsets = MAlloc((rcount+1)*8);
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
  // old_idx_hashes/old_idx_offsets stay alive through the per-file
  // loop below now (ADR 0009 addendum, experiments/84-fuzzy-rename-detection/)
  // - OfferFindFuzzyRename needs them to resolve an old blob's hash
  // back to its actual content. Freed once, after that loop, instead
  // of here.

  // Build blobs + tree from every file matching find_mask.
  //
  // Real bug found and fixed (experiments/56-offer-buffer-guard/,
  // after experiments/55-reconciledoc/'s own GPF and a follow-up hang
  // reproduced both failure modes from the same root cause): these
  // three buffers are fixed-size stack arrays with no bounds check
  // against `find_mask` matching more/bigger files than they can hold
  // - as few as ~25-40 small matched files overflows `tree_content`
  // (each entry costs 1+name_len+1+64+8 bytes), and any single file
  // over 511 bytes overflows `blob_tagged`. The overflow corrupts
  // whatever's adjacent on the stack, which manifested as either a
  // silent infinite loop or a real kernel GPF depending on exactly
  // what got clobbered - not a single deterministic failure. Guarded
  // below: a file that doesn't fit is skipped with a clear
  // host-visible message instead of silently overflowing anything.
  U8 tree_content[2048];
  I64 tlen = 4; // leave room for the U32 entry_count, filled in below
  I64 entry_count = 0;

  CDirEntry *tmpde = FilesFind(find_mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 fsize;
    U8 *fbuf = FileRead(tmpde->full_name, &fsize);

    // name = just the filename portion, after the last '/'
    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;
    I64 entry_needed = 1 + name_len + 1 + 64 + 8;

    // No `continue` here - confirmed absent from HolyC (matches
    // experiments/templeos-devkit's own documented bug-compat corpus,
    // `holyc-parser/tests/corpus/failing/007-bug-compat-bug52-continue-keyword.hc`
    // - `if (cond) continue;` isn't a keyword there, it parses as an
    // undefined identifier). Nest the rest of the loop body inside an
    // `else` instead of early-`continue`-ing past the guards.
    if (tlen + entry_needed > 2048) {
      CommPrint(1, "OFFER_SKIP tree_full %s\n", tmpde->full_name);
    } else {
      // Probe 106: was a fixed blob_tagged[512] stack buffer (the
      // real reason every file over 511 bytes used to be skipped) -
      // MAlloc'd at the file's own real size instead, same "no
      // guessed cap" pattern as ObjectPut's own fix (probe 105).
      U8 *blob_tagged = MAlloc(fsize+1);
      blob_tagged[0] = OBJ_BLOB;
      for (i=0; i<fsize; i++) blob_tagged[1+i] = fbuf[i];
      U8 blob_hash[64];
      B2Hash512Any(blob_tagged, fsize+1, blob_hash);
      Free(blob_tagged);
      ObjectPut(archive, &alen, OBJ_BLOB, fbuf, fsize);

      // ADR 0009 (experiments/70-rename-detection/): if this name
      // doesn't match anything in the parent's own tree, check
      // whether its CONTENT does before generating a fresh identity -
      // exact-content rename detection, the same scope as ADR 0004's
      // own by-name carry-forward, just keyed on the blob hash instead
      // of the name when the name lookup fails.
      U64 entity_id;
      Bool found_old = FALSE;
      if (old_tree_content != NULL) {
        U8 old_type;
        U8 old_hash[64];
        found_old = TreeFindEntry(old_tree_content, old_tree_content_len,
                                   tmpde->full_name+name_start, name_len,
                                   &old_type, old_hash, &entity_id);
        if (!found_old) {
          found_old = TreeFindEntryByHash(old_tree_content, old_tree_content_len,
                                           blob_hash, &entity_id);
        }
        // ADR 0009 addendum (experiments/84-fuzzy-rename-detection/):
        // exact name and exact content both failed - try a fuzzy
        // (edited-during-rename) match before giving up and generating
        // a fresh identity.
        if (!found_old) {
          found_old = OfferFindFuzzyRename(rbuf, old_tree_content, old_tree_content_len,
                                           old_idx_hashes, old_idx_offsets, old_idx_count,
                                           fbuf, fsize, &entity_id);
        }
      }
      if (!found_old) entity_id = GenerateEntityId();

      TreeEncodeEntry(tree_content, &tlen, tmpde->full_name+name_start, name_len,
                       OBJ_BLOB, blob_hash, entity_id);
      entry_count++;
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
  Free(old_idx_hashes);
  Free(old_idx_offsets);
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
               relation_tag, relation_target, relation_entity_id);
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
  Free(archive);
}

U0 HgitOffer(U8 *repo_path, U8 *find_mask, U8 *message, I64 message_len,
             U64 timestamp)
{
  HgitOfferWithRelation(repo_path, find_mask, message, message_len,
                         timestamp, REL_NONE, NULL, 0);
}

// ADR 0010's own real CLI-semantics decision, made once probe 90's
// standalone primitive proved solid: a NEW, separate command
// (`hgit offertree`), not a change to `hgit offer`/`HgitOfferWithRelation`
// itself - deliberately, to keep zero regression risk on the existing,
// heavily-relied-on flat-offer code path (every prior probe and
// tests/full-regression.hc's own coverage). `dir_path` (trailing "/"
// required, e.g. "C:/Home/MyProject/") is recursively offered via
// `TreeBuildRecursive` instead of one flat `FilesFind` pass. No
// relation-tag support yet (a plain offering only, matching
// `HgitOffer`'s own scope before ADR 0005 added relations) - a real,
// separate follow-up if `offertree` needs `correct`/`revert`/
// `reconcile` too.
// ADR 0010's own last deferred item, now closed (experiments/96-
// offertree-relations/): `offertree` gains the same real relation-tag
// support (`correct`/`revert`/`reconcile`) `HgitOfferWithRelation`
// already has for flat offerings - `HgitOfferTree` itself becomes a
// thin REL_NONE wrapper over this, the same relationship `HgitOffer`
// already has with `HgitOfferWithRelation`.
U0 HgitOfferTreeWithRelation(U8 *repo_path, U8 *dir_path, U8 *message, I64 message_len,
                             U64 timestamp, U8 relation_tag, U8 *relation_target,
                             U64 relation_entity_id)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  if (rsize > ARCHIVE_SANITY_MAX) {
    CommPrint(1, "OFFERTREE_REFUSED archive_absurdly_large size=%d\n", rsize);
    return;
  }

  // Probe 107: a real, computed capacity (recursive sum of every real
  // file's own size under dir_path, plus a real subdirectory count for
  // the tree objects TreeBuildRecursive will create) instead of the
  // old fixed ARCHIVE_HEADROOM - same fix as probe 106's flat-path
  // version, extended to cover offertree's own multi-tree-object shape.
  I64 new_content_bytes = 0;
  I64 new_file_count = 0;
  I64 new_subdir_count = 0;
  SumTreeFileBytes(dir_path, &new_content_bytes, &new_file_count, &new_subdir_count);
  I64 tree_object_count = new_subdir_count + 1; // +1 for the root tree

  I64 archive_cap = rsize + new_content_bytes
                   + new_file_count * OBJECT_RECORD_OVERHEAD
                   + tree_object_count * (TREE_LEVEL_MAX + OBJECT_RECORD_OVERHEAD)
                   + COMMIT_HEADROOM + OBJECT_RECORD_OVERHEAD;
  if (archive_cap > ARCHIVE_SANITY_MAX) {
    CommPrint(1, "OFFERTREE_REFUSED archive_absurdly_large size=%d\n", archive_cap);
    return;
  }
  U8 *archive = MAlloc(archive_cap);
  I64 alen;
  I64 i;
  for (i = 0; i < rsize-16; i++) archive[16+i] = rbuf[16+i];
  alen = rsize;

  U8 parent_hash[64];
  Bool has_parent = CurrentHeadRead(repo_path, parent_hash);

  U8 *old_idx_hashes = MAlloc(rcount*64 + 64);
  I64 *old_idx_offsets = MAlloc((rcount+1)*8);
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
        old_tree_content_len = ot_record_len - 1;
      }
    }
  }

  // The one real substitution: TreeBuildRecursive replaces
  // HgitOfferWithRelation's own flat FilesFind loop, recursing into
  // real subdirectories instead. old_idx_hashes/old_idx_offsets stay
  // alive through this call (needed for both the exact-hash and fuzzy
  // rename passes at every directory level), freed right after.
  U8 tree_content[4096];
  I64 tree_content_len;
  TreeBuildRecursive(dir_path, archive, &alen, rbuf, old_idx_hashes, old_idx_offsets, old_idx_count,
                     old_tree_content, old_tree_content_len,
                     tree_content, &tree_content_len);
  Free(old_idx_hashes);
  Free(old_idx_offsets);

  U8 tree_tagged[4096];
  tree_tagged[0] = OBJ_TREE;
  for (i=0; i<tree_content_len; i++) tree_tagged[1+i] = tree_content[i];
  U8 tree_hash[64];
  B2Hash512Any(tree_tagged, tree_content_len+1, tree_hash);
  ObjectPut(archive, &alen, OBJ_TREE, tree_content, tree_content_len);

  U8 commit_content[512];
  I64 clen = 0;
  CommitEncode(commit_content, &clen, tree_hash, parent_hash,
               has_parent, timestamp, message, message_len,
               relation_tag, relation_target, relation_entity_id);
  U8 commit_tagged[512];
  commit_tagged[0] = OBJ_COMMIT;
  for (i=0; i<clen; i++) commit_tagged[1+i] = commit_content[i];
  U8 commit_hash[64];
  B2Hash512Any(commit_tagged, clen+1, commit_hash);
  ObjectPut(archive, &alen, OBJ_COMMIT, commit_content, clen);

  // Object count: unlike the flat loop above (which tracks a simple
  // per-file entry_count as it goes), TreeBuildRecursive's own
  // recursion appends a variable, not-known-in-advance number of blob
  // AND tree objects at arbitrary depth - re-scanning what actually
  // landed in `archive` via the same IndexBuild every real command
  // already trusts is simpler and provably correct than threading a
  // running tally back out through arbitrary recursion depth.
  // No guessed cap (this project's own hard-won ADR 0007 lesson: a
  // fixed "surely enough" headroom number is exactly the pattern that
  // kept causing real crashes) - a real upper bound instead: no object
  // record is smaller than 73 bytes (8-byte length + 1-byte type +
  // 0-byte content + 64-byte hash), so `alen` itself bounds how many
  // objects could possibly fit in it.
  I64 max_possible_objects = alen/73 + 1;
  U8 *final_idx_hashes = MAlloc(max_possible_objects*64 + 64);
  I64 *final_idx_offsets = MAlloc((max_possible_objects+1)*8);
  I64 final_idx_count;
  IndexBuild(archive+16, alen-16, final_idx_hashes, final_idx_offsets, &final_idx_count);
  Free(final_idx_hashes);
  Free(final_idx_offsets);

  HgsWriteHeader(archive, rver, final_idx_count);
  FileWrite(repo_path, archive, alen);

  U8 log_prev_head[64];
  if (has_parent) {
    for (i=0; i<64; i++) log_prev_head[i] = parent_hash[i];
  } else {
    for (i=0; i<64; i++) log_prev_head[i] = 0;
  }
  OpLogAppend(repo_path, log_prev_head, commit_hash, timestamp);

  CurrentHeadWrite(repo_path, commit_hash);
  Free(archive);
}

U0 HgitOfferTree(U8 *repo_path, U8 *dir_path, U8 *message, I64 message_len,
                 U64 timestamp)
{
  HgitOfferTreeWithRelation(repo_path, dir_path, message, message_len,
                            timestamp, REL_NONE, NULL, 0);
}
// Merge.HC — `hgit merge <repo> <other_path_name>`: bring another
// declared path's own history into the current path.
//
// ADR 0011's own first real slice, matching ADR 0010's established
// scoping discipline - probe 97 confirmed the object model already
// supports multi-parent commits (zero code changes), probe 98 built
// and verified `FindMergeBase`; this is the real three-way tree merge
// and CLI wiring those two probes were building toward.
//
// Now recurses into nested trees too (ADR 0011's own first documented
// follow-up, experiments/100-merge-nested-trees/): a name where both
// sides' own entries (whichever of ours/theirs/base are present) all
// agree on being a real `OBJ_TREE` is recursed into via
// `MergeTreesRecursive`, reusing the exact same base/ours/theirs
// decision at each level - not a special case, the identical logic
// this file already had for blobs, just applied one directory deeper.
// A same-name entry that's an `OBJ_TREE` on one side and a plain file
// on another (a real kind mismatch) is still a genuine, honestly
// reported conflict - not attempted to auto-resolve.
//
// Scope of THIS slice (real, testable, honestly limited - see
// docs/adr/0011-merge.md, experiments/99-hgit-merge/README.md, and
// experiments/100-merge-nested-trees/README.md for the full account):
//
//   - No conflict RESOLUTION exists yet - a real conflict of any kind,
//     at any depth, aborts the ENTIRE merge with zero side effects (no
//     commit created, no HEAD moved) - the same non-destructive stance
//     every other real hgit command already takes. A user resolves
//     manually outside hgit (edit the working directory to what it
//     should be) and re-offers - there is no conflict-marker blob
//     format or resolution command yet.
//   - Trivial cases (`theirs` already an ancestor of `ours` - nothing
//     to do; `ours` unchanged since the merge base - a real
//     fast-forward, just moving the current path's HEAD) are detected
//     and handled without a merge commit, matching every real VCS's
//     own standard fast-forward behavior.
//   - A real, honest trade-off from recursing: this project's own
//     established "no side effects on abort" stance still holds for
//     anything that matters (no commit is ever created, HEAD never
//     moves, the real repo file is never touched unless the WHOLE
//     merge succeeds) - but a successful nested subtree discovered
//     before a conflict elsewhere in the tree may already have been
//     written into the in-memory `archive` scratch buffer by the time
//     the conflict is found. That buffer is simply `Free()`'d, never
//     written to the real file, on any abort - so this is invisible to
//     any real caller, not a correctness gap, just documented honestly
//     rather than silently relied upon.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Tree.HC,
// Commit.HC, Index.HC, MergeBase.HC, Meta.HC, Paths.HC, OpLog.HC.

#define MERGE_ARCHIVE_HEADROOM 20000
#define MERGE_ARCHIVE_SANITY_MAX 1000000000

// Resolves a commit hash to its own tree's content/length, via the
// same IndexLookup->IndexLookup chain every real command already
// uses (commit -> tree_hash -> tree object). Returns FALSE (not a
// crash) if either lookup fails - a broken reference is Check.HC's
// own job to report, not this file's.
Bool MergeResolveCommitTree(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                            U8 *commit_hash, U8 **out_tree_content, I64 *out_tree_len)
{
  I64 c_off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, commit_hash, &c_off_rel)) return FALSE;
  I64 c_off = 16 + c_off_rel;
  if (rbuf[c_off+8] != OBJ_COMMIT) return FALSE;
  U8 *c_content = rbuf + c_off + 9;
  U8 *tree_hash = CommitTreeHash(c_content);

  I64 t_off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &t_off_rel)) return FALSE;
  I64 t_off = 16 + t_off_rel;
  U64 t_rec_len = GetU64LE(rbuf, t_off);
  *out_tree_content = rbuf + t_off + 9;
  *out_tree_len = t_rec_len - 1;
  return TRUE;
}

// Resolves a TREE object's own content/length by its hash - the same
// IndexLookup every other real command uses. Returns FALSE (not a
// crash) if the hash isn't in the index.
Bool MergeResolveTreeByHash(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                            U8 *hash, U8 **out_content, I64 *out_len)
{
  I64 off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, hash, &off_rel)) return FALSE;
  I64 off = 16 + off_rel;
  U64 rec_len = GetU64LE(rbuf, off);
  *out_content = rbuf + off + 9;
  *out_len = rec_len - 1;
  return TRUE;
}

// Collects every distinct entry NAME across three flat trees (each
// may be NULL - a real, valid case: a subtree that doesn't exist on
// one or more sides) into `names_out` (one 256-byte slot each),
// returning the real count.
I64 MergeCollectNames(U8 *tree_a, I64 tree_a_len, U8 *tree_b, I64 tree_b_len,
                      U8 *tree_c, I64 tree_c_len, U8 *names_out)
{
  I64 name_count = 0;
  I64 which;
  for (which=0; which<3; which++) {
    U8 *t = tree_a; I64 tlen = tree_a_len;
    if (which==1) { t = tree_b; tlen = tree_b_len; }
    if (which==2) { t = tree_c; tlen = tree_c_len; }
    // No `continue` in HolyC (probe 5's own documented quirk) - guard
    // this whole loop body with `if (t != NULL)` instead of an early
    // skip.
    if (t != NULL) {
      U32 tcount = GetU32LE(t, 0);
      I64 tpos = 4;
      U32 te;
      for (te=0; te<tcount; te++) {
        U8 tname_len = t[tpos]; tpos += 1;
        U8 *tname = t + tpos; tpos += tname_len;
        tpos += 1;  // child_type
        tpos += 64; // child_hash
        tpos += 8;  // entity_id

        Bool already = FALSE;
        I64 ni;
        for (ni=0; ni<name_count && !already; ni++) {
          Bool same_name = (StrLen(names_out+ni*256) == tname_len);
          I64 ci;
          if (same_name) for (ci=0; ci<tname_len; ci++) if (names_out[ni*256+ci] != tname[ci]) same_name = FALSE;
          if (same_name) already = TRUE;
        }
        if (!already) {
          I64 cap = tname_len; if (cap > 254) cap = 254;
          I64 ci2;
          for (ci2=0; ci2<cap; ci2++) names_out[name_count*256+ci2] = tname[ci2];
          names_out[name_count*256+cap] = 0;
          name_count++;
        }
      }
    }
  }
  return name_count;
}

// The real heart of this file: three-way merges ONE tree level (base
// may be NULL - a real, valid case when a subtree is genuinely new on
// both sides), writing the merged content into
// `merged_tree_content_out`/`*merged_tree_len_out` and returning TRUE
// on success. On any conflict - here, or anywhere in a nested subtree
// - appends every real, honestly path-prefixed conflict name into
// `conflict_names_out`/`*conflict_count_out` and returns FALSE. The
// caller (another call of this same function, or `HgitMerge` at the
// top) aborts the WHOLE merge on FALSE - conflicts are never partial,
// matching ADR 0011's own "any conflict aborts everything" decision,
// now extended to work through nested levels too.
Bool MergeTreesRecursive(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                         U8 *archive, I64 *alen,
                         U8 *base_tree, I64 base_tree_len,
                         U8 *ours_tree, I64 ours_tree_len,
                         U8 *theirs_tree, I64 theirs_tree_len,
                         U8 *prefix,
                         U8 *merged_tree_content_out, I64 *merged_tree_len_out,
                         U8 *conflict_names_out, I64 *conflict_count_out)
{
  U32 ours_tcount = 0; if (ours_tree != NULL) ours_tcount = GetU32LE(ours_tree, 0);
  U32 theirs_tcount = 0; if (theirs_tree != NULL) theirs_tcount = GetU32LE(theirs_tree, 0);
  U32 base_tcount = 0; if (base_tree != NULL) base_tcount = GetU32LE(base_tree, 0);
  I64 max_names = ours_tcount + theirs_tcount + base_tcount + 1;
  U8 *names = MAlloc(max_names*256 + 256);
  I64 name_count = MergeCollectNames(ours_tree, ours_tree_len, theirs_tree, theirs_tree_len,
                                    base_tree, base_tree_len, names);

  *merged_tree_len_out = 4; // room for entry_count
  I64 merged_entry_count = 0;
  *conflict_count_out = 0;
  Bool all_ok = TRUE;

  I64 ni;
  I64 ci; // shared scratch index - reused across every sibling block
          // below rather than re-declared in each, avoiding the real,
          // recurring "duplicate member" sibling-block collision
          // (documented since probe 5, hit again in probes 94/98)
  I64 cap;
  for (ni=0; ni<name_count; ni++) {
    U8 *name = names + ni*256;
    I64 name_len = StrLen(name);

    U8 full_name[256];
    I64 fi = 0, fj;
    for (fj=0; prefix[fj]; fj++) full_name[fi++] = prefix[fj];
    I64 fcap = name_len; if (fi+fcap > 254) fcap = 254-fi;
    for (fj=0; fj<fcap; fj++) full_name[fi++] = name[fj];
    full_name[fi] = 0;

    U8 ours_type, ours_hash[64]; U64 ours_entity_id;
    Bool ours_found = FALSE;
    if (ours_tree != NULL) {
      ours_found = TreeFindEntry(ours_tree, ours_tree_len, name, name_len,
                                 &ours_type, ours_hash, &ours_entity_id);
    }
    U8 theirs_type, theirs_hash[64]; U64 theirs_entity_id;
    Bool theirs_found = FALSE;
    if (theirs_tree != NULL) {
      theirs_found = TreeFindEntry(theirs_tree, theirs_tree_len, name, name_len,
                                   &theirs_type, theirs_hash, &theirs_entity_id);
    }
    U8 base_type, base_hash[64]; U64 base_entity_id;
    Bool base_found2 = FALSE;
    if (base_tree != NULL) {
      base_found2 = TreeFindEntry(base_tree, base_tree_len, name, name_len,
                                  &base_type, base_hash, &base_entity_id);
    }

    Bool any_is_tree = (ours_found && ours_type==OBJ_TREE) ||
                       (theirs_found && theirs_type==OBJ_TREE) ||
                       (base_found2 && base_type==OBJ_TREE);
    Bool all_present_are_tree = TRUE;
    if (ours_found && ours_type != OBJ_TREE) all_present_are_tree = FALSE;
    if (theirs_found && theirs_type != OBJ_TREE) all_present_are_tree = FALSE;
    if (base_found2 && base_type != OBJ_TREE) all_present_are_tree = FALSE;

    // No `continue` in HolyC (probe 5's own documented quirk) - each
    // real case below is its own `else if` branch instead of an early
    // skip.
    if (any_is_tree && all_present_are_tree) {
      // A real subtree on at least one side, and every side that has
      // this name at all agrees it's a tree - recurse, reusing this
      // exact same function one directory level deeper.
      U8 *ours_sub = NULL; I64 ours_sub_len = 0;
      U8 *theirs_sub = NULL; I64 theirs_sub_len = 0;
      U8 *base_sub = NULL; I64 base_sub_len = 0;
      if (ours_found) MergeResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                                             ours_hash, &ours_sub, &ours_sub_len);
      if (theirs_found) MergeResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                                               theirs_hash, &theirs_sub, &theirs_sub_len);
      if (base_found2) MergeResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                                              base_hash, &base_sub, &base_sub_len);

      U8 sub_prefix[256];
      I64 spi = 0, spj;
      for (spj=0; full_name[spj]; spj++) sub_prefix[spi++] = full_name[spj];
      sub_prefix[spi++] = '/'; sub_prefix[spi] = 0;

      U8 sub_merged_content[4096];
      I64 sub_merged_len;
      U8 *sub_conflict_names = MAlloc(name_count*256 + 256); // real upper
                                                              // bound: no
                                                              // subtree can
                                                              // have more
                                                              // distinct
                                                              // names than
                                                              // this whole
                                                              // level does
      I64 sub_conflict_count;
      Bool sub_ok = MergeTreesRecursive(rbuf, idx_hashes, idx_offsets, idx_count,
                                        archive, alen,
                                        base_sub, base_sub_len, ours_sub, ours_sub_len,
                                        theirs_sub, theirs_sub_len, sub_prefix,
                                        sub_merged_content, &sub_merged_len,
                                        sub_conflict_names, &sub_conflict_count);
      if (!sub_ok) {
        all_ok = FALSE;
        I64 sci;
        for (sci=0; sci<sub_conflict_count; sci++) {
          I64 scap = StrLen(sub_conflict_names+sci*256); if (scap > 254) scap = 254;
          for (ci=0; ci<scap; ci++) conflict_names_out[(*conflict_count_out)*256+ci] = sub_conflict_names[sci*256+ci];
          conflict_names_out[(*conflict_count_out)*256+scap] = 0;
          (*conflict_count_out)++;
        }
      } else {
        U8 sub_tagged[4096];
        sub_tagged[0] = OBJ_TREE;
        I64 sti;
        for (sti=0; sti<sub_merged_len; sti++) sub_tagged[1+sti] = sub_merged_content[sti];
        U8 sub_hash[64];
        B2Hash512Any(sub_tagged, sub_merged_len+1, sub_hash);
        ObjectPut(archive, alen, OBJ_TREE, sub_merged_content, sub_merged_len);

        U64 sub_entity_id;
        if (ours_found) sub_entity_id = ours_entity_id; else sub_entity_id = theirs_entity_id;
        TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, name, name_len,
                        OBJ_TREE, sub_hash, sub_entity_id);
        merged_entry_count++;
      }
      Free(sub_conflict_names);
    } else if (any_is_tree) {
      // A real kind mismatch (file on one side, directory on
      // another, at the same name) - a genuine, honest conflict, not
      // guessed at or auto-resolved either way.
      cap = fi; if (cap > 254) cap = 254; // fi = StrLen(full_name) -
                                          // NOT name_len, which is
                                          // just the LOCAL name's own
                                          // length; full_name already
                                          // includes the real path
                                          // prefix (a genuine bug,
                                          // caught by probe 100's own
                                          // real nested-conflict test:
                                          // reported "SubB/" instead
                                          // of "SubB/z.txt" before
                                          // this fix)
      for (ci=0; ci<cap; ci++) conflict_names_out[(*conflict_count_out)*256+ci] = full_name[ci];
      conflict_names_out[(*conflict_count_out)*256+cap] = 0;
      (*conflict_count_out)++;
      all_ok = FALSE;
    } else {
      // The original flat-blob decision (unchanged from probe 99):
      // unchanged-from-base on one side takes the other side's value;
      // changed differently on both sides is a real conflict.
      Bool ours_eq_theirs = (ours_found == theirs_found);
      if (ours_eq_theirs && ours_found) {
        for (ci=0; ci<64; ci++) if (ours_hash[ci] != theirs_hash[ci]) ours_eq_theirs = FALSE;
      }

      Bool ours_eq_base = (ours_found == base_found2);
      if (ours_eq_base && ours_found) {
        for (ci=0; ci<64; ci++) if (ours_hash[ci] != base_hash[ci]) ours_eq_base = FALSE;
      }
      Bool theirs_eq_base = (theirs_found == base_found2);
      if (theirs_eq_base && theirs_found) {
        for (ci=0; ci<64; ci++) if (theirs_hash[ci] != base_hash[ci]) theirs_eq_base = FALSE;
      }

      Bool take_ours = FALSE, take_theirs = FALSE, is_conflict = FALSE;
      if (ours_eq_theirs) {
        take_ours = TRUE; // identical (or both absent) - either works
      } else if (theirs_eq_base) {
        take_ours = TRUE; // only ours changed from base
      } else if (ours_eq_base) {
        take_theirs = TRUE; // only theirs changed from base
      } else {
        is_conflict = TRUE; // both changed, differently
      }

      if (is_conflict) {
        cap = fi; if (cap > 254) cap = 254; // fi = StrLen(full_name),
                                            // not name_len - see the
                                            // sibling branch above for
                                            // why this matters
        for (ci=0; ci<cap; ci++) conflict_names_out[(*conflict_count_out)*256+ci] = full_name[ci];
        conflict_names_out[(*conflict_count_out)*256+cap] = 0;
        (*conflict_count_out)++;
        all_ok = FALSE;
      } else if (take_ours && ours_found) {
        TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, name, name_len,
                        ours_type, ours_hash, ours_entity_id);
        merged_entry_count++;
      } else if (take_theirs && theirs_found) {
        TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, name, name_len,
                        theirs_type, theirs_hash, theirs_entity_id);
        merged_entry_count++;
      }
      // else: a real deletion survived cleanly (removed on the
      // winning side, unchanged on the other) - correctly omitted
      // from the merged tree, no entry written.
    }
  }

  PutU32LE(merged_tree_content_out, 0, merged_entry_count);
  Free(names);
  return all_ok;
}

U0 HgitMerge(U8 *repo_path, U8 *other_path_name, U64 timestamp)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "MERGE_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "MERGE_ERR bad_header\n"); return; }

  U8 ours_head[64];
  if (!CurrentHeadRead(repo_path, ours_head)) {
    CommPrint(1, "MERGE_ERR no_head_on_current_path\n");
    return;
  }
  U8 theirs_head[64];
  if (!MetaReadHead(repo_path, other_path_name, theirs_head)) {
    CommPrint(1, "MERGE_ERR other_path_not_found %s\n", other_path_name);
    return;
  }

  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  U8 base_head[64];
  Bool base_found = FindMergeBase(rbuf, idx_hashes, idx_offsets, idx_count,
                                  ours_head, theirs_head, base_head);
  if (!base_found) {
    CommPrint(1, "MERGE_ERR no_common_ancestor\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }

  I64 hi;
  Bool ours_is_base = TRUE;
  for (hi=0; hi<64; hi++) if (ours_head[hi] != base_head[hi]) ours_is_base = FALSE;
  Bool theirs_is_base = TRUE;
  for (hi=0; hi<64; hi++) if (theirs_head[hi] != base_head[hi]) theirs_is_base = FALSE;

  if (theirs_is_base) {
    CommPrint(1, "MERGE_ALREADY_UP_TO_DATE\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  if (ours_is_base) {
    CurrentHeadWrite(repo_path, theirs_head);
    OpLogAppend(repo_path, ours_head, theirs_head, timestamp);
    CommPrint(1, "MERGE_FASTFORWARD\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }

  U8 *ours_tree = NULL; I64 ours_tree_len = 0;
  U8 *theirs_tree = NULL; I64 theirs_tree_len = 0;
  U8 *base_tree = NULL; I64 base_tree_len = 0;
  Bool ours_tree_ok = MergeResolveCommitTree(rbuf, idx_hashes, idx_offsets, idx_count,
                                            ours_head, &ours_tree, &ours_tree_len);
  Bool theirs_tree_ok = MergeResolveCommitTree(rbuf, idx_hashes, idx_offsets, idx_count,
                                              theirs_head, &theirs_tree, &theirs_tree_len);
  Bool base_tree_ok = MergeResolveCommitTree(rbuf, idx_hashes, idx_offsets, idx_count,
                                            base_head, &base_tree, &base_tree_len);
  if (!ours_tree_ok || !theirs_tree_ok) {
    CommPrint(1, "MERGE_ERR tree_not_found\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  if (!base_tree_ok) base_tree = NULL; // degenerate case, real not-found - handled below like a root

  if (rsize > MERGE_ARCHIVE_SANITY_MAX) {
    CommPrint(1, "MERGE_REFUSED archive_absurdly_large size=%d\n", rsize);
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  // Allocated up front (not gated on the merge outcome) so
  // MergeTreesRecursive can ObjectPut successful nested subtrees as it
  // goes - see this file's own header comment for why this is still
  // consistent with "no side effects on a real conflict": nothing
  // here is ever written to the real repo file unless the WHOLE merge
  // succeeds.
  I64 archive_cap = rsize + MERGE_ARCHIVE_HEADROOM;
  U8 *archive = MAlloc(archive_cap);
  I64 alen;
  I64 i;
  for (i=0; i<rsize-16; i++) archive[16+i] = rbuf[16+i];
  alen = rsize;

  U32 ours_tcount = GetU32LE(ours_tree, 0);
  U32 theirs_tcount = GetU32LE(theirs_tree, 0);
  U32 base_tcount = 0;
  if (base_tree != NULL) base_tcount = GetU32LE(base_tree, 0);
  I64 max_names = ours_tcount + theirs_tcount + base_tcount + 1;
  U8 *conflict_names = MAlloc(max_names*256 + 256);
  I64 conflict_count;
  U8 merged_tree_content[4096];
  I64 merged_tree_len;
  U8 root_prefix[1]; root_prefix[0] = 0;

  Bool ok = MergeTreesRecursive(rbuf, idx_hashes, idx_offsets, idx_count,
                                archive, &alen,
                                base_tree, base_tree_len, ours_tree, ours_tree_len,
                                theirs_tree, theirs_tree_len, root_prefix,
                                merged_tree_content, &merged_tree_len,
                                conflict_names, &conflict_count);

  if (!ok) {
    I64 ci2;
    for (ci2=0; ci2<conflict_count; ci2++) {
      CommPrint(1, "MERGE_CONFLICT %s\n", conflict_names+ci2*256);
    }
    CommPrint(1, "MERGE_ABORTED conflicts=%d\n", conflict_count);
    Free(idx_hashes); Free(idx_offsets); Free(conflict_names); Free(archive);
    return;
  }

  U8 merged_tree_tagged[4096];
  merged_tree_tagged[0] = OBJ_TREE;
  for (i=0; i<merged_tree_len; i++) merged_tree_tagged[1+i] = merged_tree_content[i];
  U8 merged_tree_hash[64];
  B2Hash512Any(merged_tree_tagged, merged_tree_len+1, merged_tree_hash);
  ObjectPut(archive, &alen, OBJ_TREE, merged_tree_content, merged_tree_len);

  U8 merge_parents[128];
  for (i=0; i<64; i++) merge_parents[i] = ours_head[i];
  for (i=0; i<64; i++) merge_parents[64+i] = theirs_head[i];

  U8 msg[256];
  I64 mi = 0;
  U8 *prefix = "merge ";
  I64 pj;
  for (pj=0; prefix[pj]; pj++) msg[mi++] = prefix[pj];
  I64 onl = StrLen(other_path_name);
  for (pj=0; pj<onl; pj++) msg[mi++] = other_path_name[pj];

  U8 commit_content[512];
  I64 clen = 0;
  CommitEncode(commit_content, &clen, merged_tree_hash, merge_parents, 2,
              timestamp, msg, mi, REL_NONE, NULL, 0);
  U8 commit_tagged[512];
  commit_tagged[0] = OBJ_COMMIT;
  for (i=0; i<clen; i++) commit_tagged[1+i] = commit_content[i];
  U8 merge_commit_hash[64];
  B2Hash512Any(commit_tagged, clen+1, merge_commit_hash);
  ObjectPut(archive, &alen, OBJ_COMMIT, commit_content, clen);

  I64 max_possible_objects = alen/73 + 1;
  U8 *final_idx_hashes = MAlloc(max_possible_objects*64 + 64);
  I64 *final_idx_offsets = MAlloc((max_possible_objects+1)*8);
  I64 final_idx_count;
  IndexBuild(archive+16, alen-16, final_idx_hashes, final_idx_offsets, &final_idx_count);
  Free(final_idx_hashes);
  Free(final_idx_offsets);

  HgsWriteHeader(archive, rver, final_idx_count);
  FileWrite(repo_path, archive, alen);

  OpLogAppend(repo_path, ours_head, merge_commit_hash, timestamp);
  CurrentHeadWrite(repo_path, merge_commit_hash);

  CommPrint(1, "MERGE_OK\n");

  Free(archive);
  Free(idx_hashes);
  Free(idx_offsets);
  Free(conflict_names);
}
// Logo.HC — `hgit logo`: prints the project logo as ASCII art.
//
// The art itself (docs/brand/ascii-hgit2.txt, trimmed to its real
// content rows here) and the two PNG logos (docs/brand/hgitlogo.png,
// docs/brand/hgitlogowithtext.png) were designed and provided by the
// project owner, not generated by this file - this is just the CLI
// wiring for the ASCII version.
//
// Each line is passed through CommPrint's own "%s" format arg, never
// as the format string itself - the art is full of literal '%' glyphs
// (block-shading characters), which CommPrint would otherwise parse as
// real format specifiers.

U0 HgitLogo()
{
  CommPrint(1, "%s\n", "                                      @@@                                      ");
  CommPrint(1, "%s\n", "                                    @@@@@@@                                    ");
  CommPrint(1, "%s\n", "                                  @@@@@@@@@@@                                  ");
  CommPrint(1, "%s\n", "                                @@@@@@@ @@@@@@@                                ");
  CommPrint(1, "%s\n", "                              @@@@@@@@  @@@@@@@@@                              ");
  CommPrint(1, "%s\n", "                            @@@@@@@@@  @@%@@@@@@@@@                            ");
  CommPrint(1, "%s\n", "                          @@@@@@@@@@%  %@% @@@@@@@@@                           ");
  CommPrint(1, "%s\n", "                         @@@@@@@@@@@@@  %@@%@@@@@@@@@@                         ");
  CommPrint(1, "%s\n", "                       @@@@@@@@@% %@@@@   @@@@ @@@@@@@@%                       ");
  CommPrint(1, "%s\n", "                     @@@@@@*@@@@%   %@@  @@@@% @@@@@@@@@@%                     ");
  CommPrint(1, "%s\n", "                   @@@@@@@@ @@@@@@  %@@ %@@%  @@@@@@@@@@@@@@                   ");
  CommPrint(1, "%s\n", "                 @@@@@@@@@@ @@@%@@%%@%  @@@  @@@%@@ %@@@@@@@@%                 ");
  CommPrint(1, "%s\n", "                @@@@@@@@%@@@@@@%@@@@@%  @@@@ @@@ @@% @@@@@@@@@@                ");
  CommPrint(1, "%s\n", "               %@@@@@@@@@@@@@@%  @@@@@%  %@@@@@@ %@@@%@@@@@@@@@%               ");
  CommPrint(1, "%s\n", "                @@@@@@@@ %@%@@@%    %@@@  @@@@   @@@@@@%@@@@@@%                ");
  CommPrint(1, "%s\n", "                  @@@@@@@@@ %@@@@@@%  @@  @%   %@@@@@% @@@@@@                  ");
  CommPrint(1, "%s\n", "                    @@@@@@@%    %@@@  %%    %@@@@@ @@%@@@@@                    ");
  CommPrint(1, "%s\n", "                      @@@@@@@@@% %@@@%%%  %@@@*   %@@@@@@                      ");
  CommPrint(1, "%s\n", "                       %@@@@@%@%   %@@@#  @@   #%@@@@@@%                       ");
  CommPrint(1, "%s\n", "                         @@@@@@%%%#  %@       %@@@@@@%                         ");
  CommPrint(1, "%s\n", "                           @@@@@@@@@%     %@@@@@@@@@                           ");
  CommPrint(1, "%s\n", "                             @@@@@@@@@   %@@@@@@@@                             ");
  CommPrint(1, "%s\n", "                               @@@@@@@   %@@@@@@                               ");
  CommPrint(1, "%s\n", "                                 @@@%  %% %@@@                                 ");
  CommPrint(1, "%s\n", "                                   @@@@@@@@@                                   ");
  CommPrint(1, "%s\n", "                                    @@@@@@%                                    ");
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
// Tree.HC, Commit.HC, Index.HC, Init.HC, WorkDir.HC,
// Status.HC, History.HC, See.HC, Hex.HC, Offer.HC, Logo.HC,
// Graph.HC.
//
// HGIT_VERSION (experiments/74-hgit-version/, docs/research/09-packaging-and-releases.md's
// own "not built yet" gap): a real version string, printed by `hgit
// version` and shown once by `hgit help`, so a user who's loaded
// `packaging/HgitAll.HC` can confirm what they actually have. Bumped
// by hand alongside each real GitHub release tag - this file's own
// value should always match the most recent `vX.Y.Z` release, the
// same "keep it truthful, not automated" discipline this project
// already applies to its own dispatch-table-vs-help-text pairing
// (probe 73).
//
// Versioning policy (decided at v1.0.0, per the project owner):
// 0.x releases (v0.3.0 through v0.14.0) shipped one real, verified
// change at a time - useful during heavy iteration, but 0.x forever
// reads as "not stable" once a project actually is. Going forward,
// a MAJOR version bump (X.0.0) marks a real product milestone (a
// completed milestone-phase, a headline feature, a long-standing
// bug's real root-cause fix) rather than every single probe getting
// its own patch bump - the same "don't version-churn cosmetic
// changes" instinct semver itself recommends, applied deliberately
// here rather than left as an accident of this project's own
// iteration cadence.
#define HGIT_VERSION "1.7.6"

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

// Shared by the `correct`/`revert`/`reconcile` dispatch branches
// (ADR 0005, experiments/51-relation-commands/): parses
// "<repo> <target_hex> <find_mask> <message...>" from `rest` and
// offers with the given relation tag naming the decoded target commit.
// Reports its own DISPATCH_OK/ERR so each caller doesn't repeat it.
// Parses "<repo> <target_hex> <entity_hex> <find_mask> <message...>" -
// `entity_hex` is 16 hex chars per Hex.HC's U64ToHex/HexToU64 (ADR
// 0006); pass 16 zero digits ("0000000000000000") for "not
// entity-scoped," matching Commit.HC's own 0-means-unscoped sentinel.
U0 HgitOfferRelatedCmd(U8 *rest, U8 relation_tag, U8 *cmd_name)
{
  U8 rel_repo_path[256], rel_hex[129], rel_entity_hex[17], rel_find_mask[256];
  I64 rel_p = 0;
  rel_p = ExtractToken(rest, rel_p, rel_repo_path, 256);
  rel_p = ExtractToken(rest, rel_p, rel_hex, 129);
  rel_p = ExtractToken(rest, rel_p, rel_entity_hex, 17);
  rel_p = ExtractToken(rest, rel_p, rel_find_mask, 256);
  U8 *rel_message = rest + rel_p;
  I64 rel_mlen = StrLen(rel_message);

  U8 rel_target[64];
  Bool hok = HexToHash(rel_hex, rel_target);
  if (!hok) { CommPrint(1, "DISPATCH_ERR bad_hash %s\n", rel_hex); return; }

  U64 rel_entity_id;
  Bool eok = HexToU64(rel_entity_hex, &rel_entity_id);
  if (!eok) { CommPrint(1, "DISPATCH_ERR bad_entity_id %s\n", rel_entity_hex); return; }

  U64 rel_ts = cnts.jiffies;
  HgitOfferWithRelation(rel_repo_path, rel_find_mask, rel_message, rel_mlen,
                         rel_ts, relation_tag, rel_target, rel_entity_id);
  CommPrint(1, "DISPATCH_OK %s\n", cmd_name);
}

// ADR 0010's own last deferred item, now closed (experiments/96-
// offertree-relations/): the same real relation-tag dispatch
// `HgitOfferRelatedCmd` above already provides for flat offerings,
// for `offertree`'s own recursive ones - "<repo> <target_hex>
// <entity_hex> <dir_path> <message...>" (a real directory path where
// the flat version takes a find_mask), calling
// `HgitOfferTreeWithRelation` (Offer.HC) instead of
// `HgitOfferWithRelation`.
U0 HgitOfferTreeRelatedCmd(U8 *rest, U8 relation_tag, U8 *cmd_name)
{
  U8 ort_repo_path[256], ort_hex[129], ort_entity_hex[17], ort_dir_path[256];
  I64 ort_p = 0;
  ort_p = ExtractToken(rest, ort_p, ort_repo_path, 256);
  ort_p = ExtractToken(rest, ort_p, ort_hex, 129);
  ort_p = ExtractToken(rest, ort_p, ort_entity_hex, 17);
  ort_p = ExtractToken(rest, ort_p, ort_dir_path, 256);
  U8 *ort_message = rest + ort_p;
  I64 ort_mlen = StrLen(ort_message);

  U8 ort_target[64];
  Bool ort_hok = HexToHash(ort_hex, ort_target);
  if (!ort_hok) { CommPrint(1, "DISPATCH_ERR bad_hash %s\n", ort_hex); return; }

  U64 ort_entity_id;
  Bool ort_eok = HexToU64(ort_entity_hex, &ort_entity_id);
  if (!ort_eok) { CommPrint(1, "DISPATCH_ERR bad_entity_id %s\n", ort_entity_hex); return; }

  U64 ort_ts = cnts.jiffies;
  HgitOfferTreeWithRelation(ort_repo_path, ort_dir_path, ort_message, ort_mlen,
                            ort_ts, relation_tag, ort_target, ort_entity_id);
  CommPrint(1, "DISPATCH_OK %s\n", cmd_name);
}

// `hgit help` (also `hgit` with an empty/blank string - no command at
// all): a real, discoverable command listing, closing a real
// "modern CLI" gap this project otherwise had - `DISPATCH_ERR
// unknown_command` told you what was wrong but never what to try
// instead. One line per real command below, name plus its literal
// argument shape (matching exactly what `Hgit`'s own dispatcher below
// parses for it) - kept in sync by hand, same as every other piece of
// this file's own dispatch table; nothing here is generated.
U0 HgitHelp()
{
  CommPrint(1, "HELP_BEGIN\n");
  CommPrint(1, "HELP_VERSION %s\n", HGIT_VERSION);
  CommPrint(1, "HELP_CMD init <repo_path>\n");
  CommPrint(1, "HELP_CMD status <repo_path> <find_mask> <dir_prefix>\n");
  CommPrint(1, "HELP_CMD offer <repo_path> <find_mask> <message>\n");
  CommPrint(1, "HELP_CMD offertree <repo_path> <dir_path> <message> (recursive, ADR 0010)\n");
  CommPrint(1, "HELP_CMD merge <repo_path> <other_path_name> (real conflicts abort cleanly, no resolution yet)\n");
  CommPrint(1, "HELP_CMD statustree <repo_path> <dir_path> (recursive status, ADR 0010)\n");
  CommPrint(1, "HELP_CMD history <repo_path>\n");
  CommPrint(1, "HELP_CMD see <repo_path> <commit_hex>\n");
  CommPrint(1, "HELP_CMD diff <repo_path> <commit_hex>\n");
  CommPrint(1, "HELP_CMD check <repo_path>\n");
  CommPrint(1, "HELP_CMD historydoc <repo_path> <dest.DD>\n");
  CommPrint(1, "HELP_CMD reconciledoc <repo_path> <commit_hex> <dest.DD>\n");
  CommPrint(1, "HELP_CMD reconcileoverview <repo_path> <dest.DD>\n");
  CommPrint(1, "HELP_CMD graph <repo_path> <dest.DD>\n");
  CommPrint(1, "HELP_CMD correct <repo_path> <target_hex> <entity_hex> <find_mask> <message>\n");
  CommPrint(1, "HELP_CMD revert <repo_path> <target_hex> <entity_hex> <find_mask> <message>\n");
  CommPrint(1, "HELP_CMD reconcile <repo_path> <target_hex> <entity_hex> <find_mask> <message>\n");
  CommPrint(1, "HELP_CMD correcttree <repo_path> <target_hex> <entity_hex> <dir_path> <message> (recursive, ADR 0010)\n");
  CommPrint(1, "HELP_CMD reverttree <repo_path> <target_hex> <entity_hex> <dir_path> <message> (recursive, ADR 0010)\n");
  CommPrint(1, "HELP_CMD reconciletree <repo_path> <target_hex> <entity_hex> <dir_path> <message> (recursive, ADR 0010)\n");
  CommPrint(1, "HELP_CMD   (entity_hex: 0000000000000000 for none, ADR 0006)\n");
  CommPrint(1, "HELP_CMD undo <repo_path>\n");
  CommPrint(1, "HELP_CMD redo <repo_path>\n");
  CommPrint(1, "HELP_CMD operation history <repo_path>\n");
  CommPrint(1, "HELP_CMD operation restore <repo_path> <op_index>\n");
  CommPrint(1, "HELP_CMD path list <repo_path>\n");
  CommPrint(1, "HELP_CMD path new <repo_path> <name>\n");
  CommPrint(1, "HELP_CMD path go <repo_path> <name>\n");
  CommPrint(1, "HELP_CMD path close <repo_path> <name>\n");
  CommPrint(1, "HELP_CMD export <src_repo_path> <dest_repo_path>\n");
  CommPrint(1, "HELP_CMD import <src_repo_path> <dest_repo_path>\n");
  CommPrint(1, "HELP_CMD help\n");
  CommPrint(1, "HELP_CMD version\n");
  CommPrint(1, "HELP_CMD logo\n");
  CommPrint(1, "HELP_END\n");
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

  if (StrCmp(cmd, "") == 0 || StrCmp(cmd, "help") == 0) {
    HgitHelp();
  } else if (StrCmp(cmd, "version") == 0) {
    CommPrint(1, "HGIT_VERSION %s\n", HGIT_VERSION);
  } else if (StrCmp(cmd, "logo") == 0) {
    HgitLogo();
  } else if (StrCmp(cmd, "init") == 0) {
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
  } else if (StrCmp(cmd, "check") == 0) {
    U8 check_repo_path[256];
    ExtractToken(rest, 0, check_repo_path, 256);
    HgitCheck(check_repo_path);
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
  } else if (StrCmp(cmd, "diff") == 0) {
    U8 diff_repo_path[256], diff_hex[129];
    I64 diff_p = 0;
    diff_p = ExtractToken(rest, diff_p, diff_repo_path, 256);
    diff_p = ExtractToken(rest, diff_p, diff_hex, 129);
    U8 diff_hash[64];
    Bool diff_ok = HexToHash(diff_hex, diff_hash);
    if (!diff_ok) { CommPrint(1, "DISPATCH_ERR bad_hash %s\n", diff_hex); return; }
    HgitDiff(diff_repo_path, diff_hash);
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
  } else if (StrCmp(cmd, "offertree") == 0) {
    // ADR 0010's real CLI-semantics decision: a separate command, not
    // a change to plain `offer` - see Offer.HC's own HgitOfferTree
    // comment for why.
    U8 ot_repo_path[256], ot_dir_path[256];
    I64 ot_p = 0;
    ot_p = ExtractToken(rest, ot_p, ot_repo_path, 256);
    ot_p = ExtractToken(rest, ot_p, ot_dir_path, 256);
    U8 *ot_message = rest + ot_p;
    I64 ot_mlen = StrLen(ot_message);
    U64 ot_ts = cnts.jiffies;
    HgitOfferTree(ot_repo_path, ot_dir_path, ot_message, ot_mlen, ot_ts);
    CommPrint(1, "DISPATCH_OK offertree\n");
  } else if (StrCmp(cmd, "merge") == 0) {
    // Probes 97/98's own real next step: brings another declared
    // path's history into the current one - see Merge.HC's own header
    // comment for this first slice's real, deliberate scope.
    U8 merge_repo_path[256], merge_other_path[HGIT_MAX_PATH_NAME];
    I64 merge_p = 0;
    merge_p = ExtractToken(rest, merge_p, merge_repo_path, 256);
    ExtractToken(rest, merge_p, merge_other_path, HGIT_MAX_PATH_NAME);
    U64 merge_ts = cnts.jiffies;
    HgitMerge(merge_repo_path, merge_other_path, merge_ts);
  } else if (StrCmp(cmd, "statustree") == 0) {
    // ADR 0010's own last remaining item: a separate command, not a
    // change to plain `status`'s find_mask/dir_prefix semantics - see
    // Status.HC's own HgitStatusTree comment for why.
    U8 st_repo_path[256], st_dir_path[256];
    I64 st_p = 0;
    st_p = ExtractToken(rest, st_p, st_repo_path, 256);
    st_p = ExtractToken(rest, st_p, st_dir_path, 256);
    HgitStatusTree(st_repo_path, st_dir_path);
    CommPrint(1, "DISPATCH_OK statustree\n");
  } else if (StrCmp(cmd, "correct") == 0) {
    HgitOfferRelatedCmd(rest, REL_CORRECTS, "correct");
  } else if (StrCmp(cmd, "revert") == 0) {
    HgitOfferRelatedCmd(rest, REL_REVERTS, "revert");
  } else if (StrCmp(cmd, "reconcile") == 0) {
    HgitOfferRelatedCmd(rest, REL_RECONCILES, "reconcile");
  } else if (StrCmp(cmd, "correcttree") == 0) {
    HgitOfferTreeRelatedCmd(rest, REL_CORRECTS, "correcttree");
  } else if (StrCmp(cmd, "reverttree") == 0) {
    HgitOfferTreeRelatedCmd(rest, REL_REVERTS, "reverttree");
  } else if (StrCmp(cmd, "reconciletree") == 0) {
    HgitOfferTreeRelatedCmd(rest, REL_RECONCILES, "reconciletree");
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
  } else if (StrCmp(cmd, "reconciledoc") == 0) {
    U8 rdoc_repo[256], rdoc_hex[129], rdoc_dest[256];
    I64 rdoc_p1 = ExtractToken(rest, 0, rdoc_repo, 256);
    I64 rdoc_p2 = ExtractToken(rest, rdoc_p1, rdoc_hex, 129);
    ExtractToken(rest, rdoc_p2, rdoc_dest, 256);
    U8 rdoc_hash[64];
    if (!HexToHash(rdoc_hex, rdoc_hash)) {
      CommPrint(1, "DISPATCH_ERR reconciledoc_bad_hex\n");
    } else {
      HgitReconcileDoc(rdoc_repo, rdoc_hash, rdoc_dest);
      CommPrint(1, "DISPATCH_OK reconciledoc\n");
    }
  } else if (StrCmp(cmd, "reconcileoverview") == 0) {
    U8 rov_repo[256], rov_dest[256];
    I64 rov_p = ExtractToken(rest, 0, rov_repo, 256);
    ExtractToken(rest, rov_p, rov_dest, 256);
    HgitReconcileOverview(rov_repo, rov_dest);
    CommPrint(1, "DISPATCH_OK reconcileoverview\n");
  } else if (StrCmp(cmd, "graph") == 0) {
    U8 hg_repo[256], hg_dest[256];
    I64 hg_p = ExtractToken(rest, 0, hg_repo, 256);
    ExtractToken(rest, hg_p, hg_dest, 256);
    HgitGraph(hg_repo, hg_dest);
    CommPrint(1, "DISPATCH_OK graph\n");
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
    CommPrint(1, "DISPATCH_HINT try 'help' for a full command list\n");
  }
}
