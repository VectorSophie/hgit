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
