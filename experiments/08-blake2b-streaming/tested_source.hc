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

U8 msg200[200];
msg200[0]=3;msg200[1]=10;msg200[2]=17;msg200[3]=24;msg200[4]=31;msg200[5]=38;msg200[6]=45;msg200[7]=52;msg200[8]=59;msg200[9]=66;msg200[10]=73;msg200[11]=80;msg200[12]=87;msg200[13]=94;msg200[14]=101;
msg200[15]=108;msg200[16]=115;msg200[17]=122;msg200[18]=129;msg200[19]=136;msg200[20]=143;msg200[21]=150;msg200[22]=157;msg200[23]=164;msg200[24]=171;msg200[25]=178;msg200[26]=185;msg200[27]=192;
msg200[28]=199;msg200[29]=206;msg200[30]=213;msg200[31]=220;msg200[32]=227;msg200[33]=234;msg200[34]=241;msg200[35]=248;msg200[36]=255;msg200[37]=6;msg200[38]=13;msg200[39]=20;msg200[40]=27;
msg200[41]=34;msg200[42]=41;msg200[43]=48;msg200[44]=55;msg200[45]=62;msg200[46]=69;msg200[47]=76;msg200[48]=83;msg200[49]=90;msg200[50]=97;msg200[51]=104;msg200[52]=111;msg200[53]=118;msg200[54]=125;
msg200[55]=132;msg200[56]=139;msg200[57]=146;msg200[58]=153;msg200[59]=160;msg200[60]=167;msg200[61]=174;msg200[62]=181;msg200[63]=188;msg200[64]=195;msg200[65]=202;msg200[66]=209;msg200[67]=216;
msg200[68]=223;msg200[69]=230;msg200[70]=237;msg200[71]=244;msg200[72]=251;msg200[73]=2;msg200[74]=9;msg200[75]=16;msg200[76]=23;msg200[77]=30;msg200[78]=37;msg200[79]=44;msg200[80]=51;msg200[81]=58;
msg200[82]=65;msg200[83]=72;msg200[84]=79;msg200[85]=86;msg200[86]=93;msg200[87]=100;msg200[88]=107;msg200[89]=114;msg200[90]=121;msg200[91]=128;msg200[92]=135;msg200[93]=142;msg200[94]=149;
msg200[95]=156;msg200[96]=163;msg200[97]=170;msg200[98]=177;msg200[99]=184;msg200[100]=191;msg200[101]=198;msg200[102]=205;msg200[103]=212;msg200[104]=219;msg200[105]=226;msg200[106]=233;
msg200[107]=240;msg200[108]=247;msg200[109]=254;msg200[110]=5;msg200[111]=12;msg200[112]=19;msg200[113]=26;msg200[114]=33;msg200[115]=40;msg200[116]=47;msg200[117]=54;msg200[118]=61;msg200[119]=68;
msg200[120]=75;msg200[121]=82;msg200[122]=89;msg200[123]=96;msg200[124]=103;msg200[125]=110;msg200[126]=117;msg200[127]=124;msg200[128]=131;msg200[129]=138;msg200[130]=145;msg200[131]=152;
msg200[132]=159;msg200[133]=166;msg200[134]=173;msg200[135]=180;msg200[136]=187;msg200[137]=194;msg200[138]=201;msg200[139]=208;msg200[140]=215;msg200[141]=222;msg200[142]=229;msg200[143]=236;
msg200[144]=243;msg200[145]=250;msg200[146]=1;msg200[147]=8;msg200[148]=15;msg200[149]=22;msg200[150]=29;msg200[151]=36;msg200[152]=43;msg200[153]=50;msg200[154]=57;msg200[155]=64;msg200[156]=71;
msg200[157]=78;msg200[158]=85;msg200[159]=92;msg200[160]=99;msg200[161]=106;msg200[162]=113;msg200[163]=120;msg200[164]=127;msg200[165]=134;msg200[166]=141;msg200[167]=148;msg200[168]=155;
msg200[169]=162;msg200[170]=169;msg200[171]=176;msg200[172]=183;msg200[173]=190;msg200[174]=197;msg200[175]=204;msg200[176]=211;msg200[177]=218;msg200[178]=225;msg200[179]=232;msg200[180]=239;
msg200[181]=246;msg200[182]=253;msg200[183]=4;msg200[184]=11;msg200[185]=18;msg200[186]=25;msg200[187]=32;msg200[188]=39;msg200[189]=46;msg200[190]=53;msg200[191]=60;msg200[192]=67;msg200[193]=74;
msg200[194]=81;msg200[195]=88;msg200[196]=95;msg200[197]=102;msg200[198]=109;msg200[199]=116;
U8 msg300[300];
msg300[0]=1;msg300[1]=14;msg300[2]=27;msg300[3]=40;msg300[4]=53;msg300[5]=66;msg300[6]=79;msg300[7]=92;msg300[8]=105;msg300[9]=118;msg300[10]=131;msg300[11]=144;msg300[12]=157;msg300[13]=170;
msg300[14]=183;msg300[15]=196;msg300[16]=209;msg300[17]=222;msg300[18]=235;msg300[19]=248;msg300[20]=5;msg300[21]=18;msg300[22]=31;msg300[23]=44;msg300[24]=57;msg300[25]=70;msg300[26]=83;
msg300[27]=96;msg300[28]=109;msg300[29]=122;msg300[30]=135;msg300[31]=148;msg300[32]=161;msg300[33]=174;msg300[34]=187;msg300[35]=200;msg300[36]=213;msg300[37]=226;msg300[38]=239;msg300[39]=252;
msg300[40]=9;msg300[41]=22;msg300[42]=35;msg300[43]=48;msg300[44]=61;msg300[45]=74;msg300[46]=87;msg300[47]=100;msg300[48]=113;msg300[49]=126;msg300[50]=139;msg300[51]=152;msg300[52]=165;
msg300[53]=178;msg300[54]=191;msg300[55]=204;msg300[56]=217;msg300[57]=230;msg300[58]=243;msg300[59]=0;msg300[60]=13;msg300[61]=26;msg300[62]=39;msg300[63]=52;msg300[64]=65;msg300[65]=78;
msg300[66]=91;msg300[67]=104;msg300[68]=117;msg300[69]=130;msg300[70]=143;msg300[71]=156;msg300[72]=169;msg300[73]=182;msg300[74]=195;msg300[75]=208;msg300[76]=221;msg300[77]=234;msg300[78]=247;
msg300[79]=4;msg300[80]=17;msg300[81]=30;msg300[82]=43;msg300[83]=56;msg300[84]=69;msg300[85]=82;msg300[86]=95;msg300[87]=108;msg300[88]=121;msg300[89]=134;msg300[90]=147;msg300[91]=160;
msg300[92]=173;msg300[93]=186;msg300[94]=199;msg300[95]=212;msg300[96]=225;msg300[97]=238;msg300[98]=251;msg300[99]=8;msg300[100]=21;msg300[101]=34;msg300[102]=47;msg300[103]=60;msg300[104]=73;
msg300[105]=86;msg300[106]=99;msg300[107]=112;msg300[108]=125;msg300[109]=138;msg300[110]=151;msg300[111]=164;msg300[112]=177;msg300[113]=190;msg300[114]=203;msg300[115]=216;msg300[116]=229;
msg300[117]=242;msg300[118]=255;msg300[119]=12;msg300[120]=25;msg300[121]=38;msg300[122]=51;msg300[123]=64;msg300[124]=77;msg300[125]=90;msg300[126]=103;msg300[127]=116;msg300[128]=129;
msg300[129]=142;msg300[130]=155;msg300[131]=168;msg300[132]=181;msg300[133]=194;msg300[134]=207;msg300[135]=220;msg300[136]=233;msg300[137]=246;msg300[138]=3;msg300[139]=16;msg300[140]=29;
msg300[141]=42;msg300[142]=55;msg300[143]=68;msg300[144]=81;msg300[145]=94;msg300[146]=107;msg300[147]=120;msg300[148]=133;msg300[149]=146;msg300[150]=159;msg300[151]=172;msg300[152]=185;
msg300[153]=198;msg300[154]=211;msg300[155]=224;msg300[156]=237;msg300[157]=250;msg300[158]=7;msg300[159]=20;msg300[160]=33;msg300[161]=46;msg300[162]=59;msg300[163]=72;msg300[164]=85;msg300[165]=98;
msg300[166]=111;msg300[167]=124;msg300[168]=137;msg300[169]=150;msg300[170]=163;msg300[171]=176;msg300[172]=189;msg300[173]=202;msg300[174]=215;msg300[175]=228;msg300[176]=241;msg300[177]=254;
msg300[178]=11;msg300[179]=24;msg300[180]=37;msg300[181]=50;msg300[182]=63;msg300[183]=76;msg300[184]=89;msg300[185]=102;msg300[186]=115;msg300[187]=128;msg300[188]=141;msg300[189]=154;
msg300[190]=167;msg300[191]=180;msg300[192]=193;msg300[193]=206;msg300[194]=219;msg300[195]=232;msg300[196]=245;msg300[197]=2;msg300[198]=15;msg300[199]=28;msg300[200]=41;msg300[201]=54;
msg300[202]=67;msg300[203]=80;msg300[204]=93;msg300[205]=106;msg300[206]=119;msg300[207]=132;msg300[208]=145;msg300[209]=158;msg300[210]=171;msg300[211]=184;msg300[212]=197;msg300[213]=210;
msg300[214]=223;msg300[215]=236;msg300[216]=249;msg300[217]=6;msg300[218]=19;msg300[219]=32;msg300[220]=45;msg300[221]=58;msg300[222]=71;msg300[223]=84;msg300[224]=97;msg300[225]=110;msg300[226]=123;
msg300[227]=136;msg300[228]=149;msg300[229]=162;msg300[230]=175;msg300[231]=188;msg300[232]=201;msg300[233]=214;msg300[234]=227;msg300[235]=240;msg300[236]=253;msg300[237]=10;msg300[238]=23;
msg300[239]=36;msg300[240]=49;msg300[241]=62;msg300[242]=75;msg300[243]=88;msg300[244]=101;msg300[245]=114;msg300[246]=127;msg300[247]=140;msg300[248]=153;msg300[249]=166;msg300[250]=179;
msg300[251]=192;msg300[252]=205;msg300[253]=218;msg300[254]=231;msg300[255]=244;msg300[256]=1;msg300[257]=14;msg300[258]=27;msg300[259]=40;msg300[260]=53;msg300[261]=66;msg300[262]=79;msg300[263]=92;
msg300[264]=105;msg300[265]=118;msg300[266]=131;msg300[267]=144;msg300[268]=157;msg300[269]=170;msg300[270]=183;msg300[271]=196;msg300[272]=209;msg300[273]=222;msg300[274]=235;msg300[275]=248;
msg300[276]=5;msg300[277]=18;msg300[278]=31;msg300[279]=44;msg300[280]=57;msg300[281]=70;msg300[282]=83;msg300[283]=96;msg300[284]=109;msg300[285]=122;msg300[286]=135;msg300[287]=148;msg300[288]=161;
msg300[289]=174;msg300[290]=187;msg300[291]=200;msg300[292]=213;msg300[293]=226;msg300[294]=239;msg300[295]=252;msg300[296]=9;msg300[297]=22;msg300[298]=35;msg300[299]=48;
U8 out200[64];
B2StreamInit();
B2StreamUpdate(msg200, 200);
B2StreamFinal(out200);
I64 k;
CommPrint(1,"digest200:");
for (k=0;k<64;k++) CommPrint(1,"%02X",out200[k]);
CommPrint(1,"\n");

// same message, but fed via THREE separate Update calls spanning block
// boundaries unevenly, to exercise cross-call buffering specifically.
U8 out200b[64];
B2StreamInit();
B2StreamUpdate(msg200, 90);
B2StreamUpdate(msg200+90, 47);
B2StreamUpdate(msg200+137, 63);
B2StreamFinal(out200b);
Bool match200 = TRUE;
for (k=0;k<64;k++) if (out200[k]!=out200b[k]) match200=FALSE;
CommPrint(1,"split_call_matches_single_call=%d\n", match200);

U8 out300[64];
B2StreamInit();
B2StreamUpdate(msg300, 300);
B2StreamFinal(out300);
CommPrint(1,"digest300:");
for (k=0;k<64;k++) CommPrint(1,"%02X",out300[k]);
CommPrint(1,"\n");

// regression: streaming API on "abc" must match the existing
// single-block B2Hash512("abc") result already verified against RFC 7693.
U8 abcbuf[3]; abcbuf[0]='a';abcbuf[1]='b';abcbuf[2]='c';
U8 out_abc_stream[64];
B2StreamInit();
B2StreamUpdate(abcbuf, 3);
B2StreamFinal(out_abc_stream);
U8 out_abc_single[64];
B2Hash512(abcbuf, 3, out_abc_single);
Bool abc_match = TRUE;
for (k=0;k<64;k++) if (out_abc_stream[k]!=out_abc_single[k]) abc_match=FALSE;
CommPrint(1,"abc_stream_matches_single=%d\n", abc_match);
