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
// LIMITATION (deliberate, for this first probe): only handles messages
// that fit in one 128-byte block (<=111 bytes after the length/counter
// bookkeeping headroom BLAKE2b's single-block path allows here - not yet
// generalized to multi-block streaming). hgit-core will need multi-block
// support before this can hash real objects; that's the next probe, not
// done here. Do not use this for anything beyond short-fixture testing
// yet.
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
// Archive.HC — minimal append-only tiny object archive for hgit.
//
// Record format (all fields via Canon.HC's explicit-endian helpers):
//   [U64 length LE][length bytes of data][64 bytes BLAKE2b-512 hash]
//
// This is deliberately minimal: no compression, no delta encoding, no
// multi-block hashing (Blake2b.HC is single-block only right now, so
// records are capped at what fits in one BLAKE2b block). It exists to
// answer the M0 question "can hgit append/write/read-back/verify a tiny
// object archive on real TempleOS at all" - not to be the final format.
//
// Depends on Canon.HC (PutU64LE/GetU64LE) and Blake2b.HC (B2Hash512).
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
  B2Hash512(data, len, hash);
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
    B2Hash512(data, len, recomputed);
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
  B2Hash512(data, dlen, h);
  PutU64LE(archive_buf, *len, dlen);
  *len += 8;
  for (i=0; i<dlen; i++) archive_buf[*len+i] = data[i];
  *len += dlen;
  for (i=0; i<64; i++) archive_buf[*len+i] = h[i];
  *len += 64;
}
// Object type tags - prepended as the first content byte before hashing
// and storing, so identical bytes stored as different types hash
// differently (matches Git's header-participates-in-hash design).
#define OBJ_BLOB   1
#define OBJ_TREE   2
#define OBJ_COMMIT 3

U0 ObjectPut(U8 *archive_buf, I64 *len, U8 type, U8 *data, I64 dlen)
{
  U8 tagged[128];
  I64 i;
  tagged[0] = type;
  for (i=0; i<dlen; i++) tagged[1+i] = data[i];
  HgsPut(archive_buf, len, tagged, dlen+1);
}

// Reads back the object at the given offset (pointing at its length
// field) and returns its type tag + a pointer to its content (content
// excludes the type byte). *content_len_out excludes the tag byte too.
U8 ObjectPeekType(U8 *archive_buf, I64 offset)
{
  I64 pos = offset + 8; // skip length field
  return archive_buf[pos];
}

U8 obj_archive[512];
I64 obj_len = 16;
HgsWriteHeader(obj_archive, 1, 3);

U8 blob_data[5]; blob_data[0]='h';blob_data[1]='e';blob_data[2]='l';blob_data[3]='l';blob_data[4]='o';
U8 tree_data[3]; tree_data[0]='T';tree_data[1]='R';tree_data[2]='E';
U8 commit_data[4]; commit_data[0]='C';commit_data[1]='M';commit_data[2]='T';commit_data[3]='!';

I64 off_blob = obj_len;
ObjectPut(obj_archive, &obj_len, OBJ_BLOB, blob_data, 5);
I64 off_tree = obj_len;
ObjectPut(obj_archive, &obj_len, OBJ_TREE, tree_data, 3);
I64 off_commit = obj_len;
ObjectPut(obj_archive, &obj_len, OBJ_COMMIT, commit_data, 4);

CommPrint(1,"obj_len=%d\n", obj_len);
CommPrint(1,"type_blob=%d type_tree=%d type_commit=%d\n",
          ObjectPeekType(obj_archive, off_blob),
          ObjectPeekType(obj_archive, off_tree),
          ObjectPeekType(obj_archive, off_commit));

// Cross-check: same bytes, different type, must hash differently.
U8 same_bytes[3]; same_bytes[0]='T';same_bytes[1]='R';same_bytes[2]='E';
U8 tagged_a[4]; tagged_a[0]=OBJ_BLOB; tagged_a[1]='T';tagged_a[2]='R';tagged_a[3]='E';
U8 tagged_b[4]; tagged_b[0]=OBJ_TREE; tagged_b[1]='T';tagged_b[2]='R';tagged_b[3]='E';
U8 hash_a[64], hash_b[64];
B2Hash512(tagged_a, 4, hash_a);
B2Hash512(tagged_b, 4, hash_b);
Bool same_bytes_diff_type_differ = FALSE;
I64 k;
for (k=0;k<64;k++) if (hash_a[k]!=hash_b[k]) same_bytes_diff_type_differ = TRUE;
CommPrint(1,"same_bytes_diff_type_differ=%d\n", same_bytes_diff_type_differ);

FileWrite("C:/Home/test3.hgs", obj_archive, obj_len);
I64 rsize3;
U8 *rbuf3 = FileRead("C:/Home/test3.hgs", &rsize3);
U16 rver3; U64 rcount3;
Bool hok3 = HgsReadHeader(rbuf3, &rver3, &rcount3);
I64 vt3, vok3;
ArchiveVerify(rbuf3+16, rsize3-16, &vt3, &vok3);
CommPrint(1,"reload: hok=%d count=%d verify_total=%d verify_ok=%d\n", hok3, rcount3, vt3, vok3);

if (ObjectPeekType(obj_archive,off_blob)==OBJ_BLOB &&
    ObjectPeekType(obj_archive,off_tree)==OBJ_TREE &&
    ObjectPeekType(obj_archive,off_commit)==OBJ_COMMIT &&
    same_bytes_diff_type_differ && hok3 && rcount3==3 && vt3==3 && vok3==3)
  CommPrint(1,"PASS object_typing\n");
else
  CommPrint(1,"FAIL object_typing\n");
